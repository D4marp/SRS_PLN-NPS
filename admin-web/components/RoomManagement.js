'use client';

import { useState } from 'react';
import { Trash2, Plus } from 'lucide-react';

const ROOM_CLASSES = [
  'Meeting Room',
  'Conference Room',
  'Auditorium',
  'Study Room',
  'Training Room',
  'Board Room',
  'Boardroom',
  'Office',
  'Class Room',
  'Lab',
  'Lecture Hall',
];

const fieldClass =
  'h-10 w-full rounded-xl border border-slate-200 bg-white px-3 text-sm text-slate-700 outline-none transition focus:border-sky-400';

export default function RoomManagement({
  rooms,
  loading,
  onCreateRoom,
  onUpdateRoom,
  onDeleteRoom,
  creatingRoom,
  actionBusyKey,
}) {
  const [showForm, setShowForm] = useState(false);
  const [editingRoom, setEditingRoom] = useState(null);
  const [formState, setFormState] = useState({
    name: '',
    location: '',
    maxGuests: 1,
    roomClass: 'Meeting Room',
    description: '',
  });

  const handleOpenCreate = () => {
    setEditingRoom(null);
    setFormState({
      name: '',
      location: '',
      maxGuests: 1,
      roomClass: 'Meeting Room',
      description: '',
    });
    setShowForm(true);
  };

  const handleOpenEdit = (room) => {
    setEditingRoom(room);
    setFormState({
      name: room.name || '',
      location: room.location || '',
      maxGuests: room.maxGuests || 1,
      roomClass: room.roomClass || 'Meeting Room',
      description: room.description || '',
    });
    setShowForm(true);
  };

  const handleCancel = () => {
    setShowForm(false);
    setEditingRoom(null);
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!formState.name.trim()) {
      window.alert('Nama ruangan tidak boleh kosong');
      return;
    }

    const payload = {
      name: formState.name.trim(),
      location: formState.location.trim() || null,
      maxGuests: Number(formState.maxGuests) || 1,
      roomClass: formState.roomClass,
      description: formState.description.trim() || null,
    };

    try {
      if (editingRoom) {
        await onUpdateRoom(editingRoom.id, payload);
      } else {
        await onCreateRoom(payload);
      }
      handleCancel();
    } catch (err) {
      console.error('Submit error:', err);
    }
  };

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <header className="mb-4 flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-semibold text-slate-900">Manajemen Ruangan</h2>
          <p className="mt-1 text-sm text-slate-700">Kelola daftar ruangan yang tersedia untuk booking.</p>
        </div>

        {!showForm && (
          <button
            type="button"
            className="inline-flex h-10 items-center gap-2 rounded-xl bg-gradient-to-r from-[#0099ff] to-[#0077cc] px-4 text-sm font-semibold text-white transition hover:opacity-90"
            onClick={handleOpenCreate}
          >
            <Plus size={16} />
            Tambah Ruangan
          </button>
        )}
      </header>

      {showForm && (
        <form className="mb-6 rounded-xl border border-sky-100 bg-sky-50 p-4" onSubmit={handleSubmit}>
          <h3 className="mb-3 text-sm font-semibold text-slate-900">
            {editingRoom ? `Edit: ${editingRoom.name}` : 'Tambah Ruangan Baru'}
          </h3>

          <div className="grid gap-3">
            <input
              className={fieldClass}
              type="text"
              value={formState.name}
              onChange={(e) => setFormState((prev) => ({ ...prev, name: e.target.value }))}
              placeholder="Nama ruangan (wajib)"
              required
            />

            <input
              className={fieldClass}
              type="text"
              value={formState.location}
              onChange={(e) => setFormState((prev) => ({ ...prev, location: e.target.value }))}
              placeholder="Lokasi (opsional)"
            />

            <div className="grid grid-cols-2 gap-3">
              <select
                className={fieldClass}
                value={formState.roomClass}
                onChange={(e) => setFormState((prev) => ({ ...prev, roomClass: e.target.value }))}
              >
                {ROOM_CLASSES.map((cls) => (
                  <option key={cls} value={cls}>
                    {cls}
                  </option>
                ))}
              </select>

              <input
                className={fieldClass}
                type="number"
                min="1"
                value={formState.maxGuests}
                onChange={(e) =>
                  setFormState((prev) => ({ ...prev, maxGuests: parseInt(e.target.value, 10) || 1 }))
                }
                placeholder="Kapasitas"
              />
            </div>

            <textarea
              className={`${fieldClass} !h-auto resize-none py-2`}
              value={formState.description}
              onChange={(e) => setFormState((prev) => ({ ...prev, description: e.target.value }))}
              placeholder="Deskripsi (opsional)"
              rows="2"
            />

            <div className="flex gap-2">
              <button
                type="submit"
                className="flex-1 rounded-xl bg-gradient-to-r from-[#0099ff] to-[#0077cc] px-3 py-2 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
                disabled={creatingRoom}
              >
                {creatingRoom ? 'Mengirim...' : editingRoom ? 'Update' : 'Tambah'}
              </button>
              <button
                type="button"
                className="flex-1 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50"
                onClick={handleCancel}
              >
                Batal
              </button>
            </div>
          </div>
        </form>
      )}

      {loading ? (
        <div className="flex items-center justify-center gap-2 py-8 text-slate-600">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-sky-200 border-t-sky-500" />
          <span className="text-sm">Memuat ruangan...</span>
        </div>
      ) : rooms.length === 0 ? (
        <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50 p-6 text-center text-sm text-slate-600">
          Belum ada ruangan yang terdaftar. Klik &quot;Tambah Ruangan&quot; untuk membuat yang baru.
        </div>
      ) : (
        <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          {rooms.map((room) => (
            <article
              key={room.id}
              className="rounded-xl border border-slate-200 bg-slate-50 p-4 transition hover:border-sky-300 hover:bg-sky-50"
            >
              <div className="mb-3 flex items-start justify-between gap-2">
                <div>
                  <p className="font-semibold text-slate-900">{room.name}</p>
                  <p className="text-xs text-slate-600">{room.roomClass}</p>
                </div>
                <button
                  type="button"
                  className="rounded-lg border border-red-200 bg-red-50 p-2 text-red-600 transition hover:bg-red-100 disabled:opacity-60"
                  onClick={() => {
                    if (window.confirm(`Hapus ruangan "${room.name}"?`)) {
                      onDeleteRoom(room.id);
                    }
                  }}
                  disabled={actionBusyKey === `delete:${room.id}`}
                >
                  <Trash2 size={14} />
                </button>
              </div>

              <div className="space-y-1 text-xs text-slate-700">
                {room.location && <p>📍 {room.location}</p>}
                <p>👥 Kapasitas: {room.maxGuests} orang</p>
                {room.description && <p className="text-slate-600">{room.description}</p>}
              </div>

              <button
                type="button"
                className="mt-3 w-full rounded-lg bg-white px-2 py-1.5 text-xs font-semibold text-sky-600 transition hover:bg-sky-50"
                onClick={() => handleOpenEdit(room)}
              >
                Edit
              </button>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
