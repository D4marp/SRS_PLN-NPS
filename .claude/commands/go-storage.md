# Go Storage

Implementasikan file upload dan serving untuk gambar ruangan, menggantikan Firebase Storage.

## Pemetaan dari Firebase Storage

| Firebase Storage | Go Backend |
|-----------------|------------|
| `ref().child('room_images').child('${timestamp}.jpg').putFile(file)` | `POST /api/rooms/:id/images` (multipart/form-data) |
| `getDownloadURL()` → `https://firebasestorage.googleapis.com/...` | `GET /uploads/{filename}` → served dari local dir atau MinIO |
| `room_images/{timestamp}.jpg` path | `./uploads/rooms/{roomId}/{uuid}.jpg` |

## Strategy Storage

Gunakan **local filesystem** untuk development:
- Upload ke `./uploads/rooms/{roomId}/{uuid}.ext`
- Serve via `r.Static("/uploads", "./uploads")`
- URL format: `http://localhost:8080/uploads/rooms/{roomId}/{filename}`

Untuk production, ganti dengan **MinIO** (self-hosted S3-compatible):
- Tidak perlu kode berbeda di handler, cukup mount MinIO bucket sebagai filesystem
- Atau upgrade ke `minio-go` SDK

## Tugas

Buat `backend/internal/handlers/storage_handler.go`:

```go
package handlers

import (
    "context"
    "fmt"
    "io"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/bookify-rooms/backend/internal/utils"
)

type StorageHandler struct {
    db         *pgxpool.Pool
    uploadsDir string
    baseURL    string
}

func NewStorageHandler(db *pgxpool.Pool, uploadsDir, baseURL string) *StorageHandler {
    // Pastikan direktori uploads ada
    os.MkdirAll(uploadsDir, 0755)
    return &StorageHandler{db: db, uploadsDir: uploadsDir, baseURL: baseURL}
}

// UploadRoomImage godoc
// POST /api/rooms/:id/images  [requires: Auth, role=admin]
// Content-Type: multipart/form-data
// Field: "image" (file)
func (h *StorageHandler) UploadRoomImage(c *gin.Context) {
    roomID := c.Param("id")

    // Verify room exists
    var exists bool
    h.db.QueryRow(context.Background(),
        "SELECT EXISTS(SELECT 1 FROM rooms WHERE id = $1)", roomID).Scan(&exists)
    if !exists {
        utils.Error(c, http.StatusNotFound, "room not found")
        return
    }

    // Parse uploaded file (max 5MB)
    c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 5<<20)
    file, header, err := c.Request.FormFile("image")
    if err != nil {
        utils.Error(c, http.StatusBadRequest, "failed to read image: "+err.Error())
        return
    }
    defer file.Close()

    // Validasi extension
    ext := strings.ToLower(filepath.Ext(header.Filename))
    allowedExts := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true}
    if !allowedExts[ext] {
        utils.Error(c, http.StatusBadRequest, "only jpg, jpeg, png, webp are allowed")
        return
    }

    // Buat direktori untuk room
    roomDir := filepath.Join(h.uploadsDir, "rooms", roomID)
    if err := os.MkdirAll(roomDir, 0755); err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to create directory")
        return
    }

    // Generate unique filename
    filename := fmt.Sprintf("%d_%s%s", time.Now().UnixMilli(), uuid.New().String()[:8], ext)
    destPath := filepath.Join(roomDir, filename)

    // Simpan file
    dst, err := os.Create(destPath)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to save image")
        return
    }
    defer dst.Close()

    if _, err := io.Copy(dst, file); err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to write image")
        return
    }

    // Build public URL
    imageURL := fmt.Sprintf("%s/uploads/rooms/%s/%s", h.baseURL, roomID, filename)

    // Append URL ke rooms.image_urls array
    _, err = h.db.Exec(context.Background(),
        `UPDATE rooms
         SET image_urls = array_append(image_urls, $1), updated_at = $2
         WHERE id = $3`,
        imageURL, time.Now().UnixMilli(), roomID,
    )
    if err != nil {
        // Hapus file yang sudah diupload jika DB update gagal
        os.Remove(destPath)
        utils.Error(c, http.StatusInternalServerError, "failed to update room")
        return
    }

    utils.Success(c, http.StatusCreated, gin.H{
        "imageUrl": imageURL,
        "filename": filename,
    })
}

// DeleteRoomImage godoc
// DELETE /api/rooms/:id/images  [requires: Auth, role=admin]
// Body: {"imageUrl": "http://..."}
func (h *StorageHandler) DeleteRoomImage(c *gin.Context) {
    roomID := c.Param("id")

    var req struct {
        ImageURL string `json:"imageUrl" binding:"required"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    // Hapus dari DB array
    _, err := h.db.Exec(context.Background(),
        `UPDATE rooms
         SET image_urls = array_remove(image_urls, $1), updated_at = $2
         WHERE id = $3`,
        req.ImageURL, time.Now().UnixMilli(), roomID,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to update room")
        return
    }

    // Hapus file fisik dari disk
    // Parse path dari URL: .../uploads/rooms/{roomId}/{filename}
    urlParts := strings.Split(req.ImageURL, "/uploads/")
    if len(urlParts) > 1 {
        filePath := filepath.Join(h.uploadsDir, urlParts[1])
        os.Remove(filePath) // ignore error jika file sudah tidak ada
    }

    utils.SuccessMessage(c, http.StatusOK, "image deleted", nil)
}
```

## Setup Static File Serving

Di `internal/server/router.go`:

```go
// Serve uploaded files sebagai static assets
r.Static("/uploads", cfg.UploadsDir)

// Storage routes (admin only)
storageH := handlers.NewStorageHandler(db, cfg.UploadsDir, cfg.BaseURL)

// Image management untuk rooms
r.POST("/api/rooms/:id/images",
    authMiddleware, adminMiddleware,
    storageH.UploadRoomImage)
r.DELETE("/api/rooms/:id/images",
    authMiddleware, adminMiddleware,
    storageH.DeleteRoomImage)
```

## Tambahkan ke Config

Di `internal/config/config.go`, tambahkan:
```go
type Config struct {
    // ... existing fields ...
    BaseURL       string  // e.g. "http://localhost:8080"
}

// Di Load():
BaseURL: getEnv("BASE_URL", "http://localhost:8080"),
```

## Tambahkan ke `.env.example`

```
BASE_URL=http://localhost:8080
```

## Testing dengan cURL

```bash
# Upload gambar ke room
curl -X POST http://localhost:8080/api/rooms/{room-id}/images \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -F "image=@/path/to/image.jpg"
# Response: {"imageUrl": "http://localhost:8080/uploads/rooms/{id}/timestamp_uuid.jpg"}

# Akses gambar (public)
curl http://localhost:8080/uploads/rooms/{room-id}/{filename}.jpg

# Delete image
curl -X DELETE http://localhost:8080/api/rooms/{room-id}/images \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imageUrl": "http://localhost:8080/uploads/rooms/{id}/filename.jpg"}'
```

## Catatan Production

Untuk production:
1. **MinIO** (recommended): Jalankan MinIO container, gunakan `minio-go` SDK
2. **AWS S3**: Gunakan `aws-sdk-go-v2`
3. **Cloudflare R2**: S3-compatible, murah

Perubahan yang diperlukan di Flutter app:
- `imageUrls` di `Room` model sekarang berisi URL absolut ke Go backend
- Upload gambar via HTTP multipart ke `/api/rooms/:id/images`
- Hapus semua `FirebaseStorage.instance.ref()` calls
