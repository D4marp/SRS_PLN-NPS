package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Port              string
	DatabaseURL       string
	JWTSecret         string
	JWTExpiry         string // e.g. "168h"
	UploadsDir        string
	BaseURL           string
	AllowedOrigins    []string
	SuperAdminEmail   string
	SuperAdminPassword string
}

func Load() *Config {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	return &Config{
		Port:               getEnv("PORT", "8080"),
		DatabaseURL:        getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/bookify?sslmode=disable"),
		JWTSecret:          getEnv("JWT_SECRET", "change-this-secret-in-production"),
		JWTExpiry:          getEnv("JWT_EXPIRY", "168h"),
		UploadsDir:         getEnv("UPLOADS_DIR", "./uploads"),
		BaseURL:            getEnv("BASE_URL", "http://localhost:8080"),
		AllowedOrigins:     []string{getEnv("ALLOWED_ORIGINS", "*")},
		SuperAdminEmail:    getEnv("SUPERADMIN_EMAIL", ""),
		SuperAdminPassword: getEnv("SUPERADMIN_PASSWORD", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
