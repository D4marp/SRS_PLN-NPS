'use client';

import { useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function toDateKey(value) {
  const date = new Date(Number(value));
  if (Number.isNaN(date.getTime())) return null;
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function prettyDateFromKey(dateKey) {
  if (!dateKey) return '-';
  const date = new Date(`${dateKey}T00:00:00`);
  return date.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}

function buildRows(baseDate) {
  const year = baseDate.getFullYear();
  const month = baseDate.getMonth();
  const firstDate = new Date(year, month, 1);

  const startOffset = (firstDate.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const prevMonthDays = new Date(year, month, 0).getDate();

  const cells = [];

  for (let i = 0; i < startOffset; i += 1) {
    const day = prevMonthDays - startOffset + i + 1;
    cells.push({ type: 'pad', id: `prev-${i}`, day });
  }

  for (let day = 1; day <= daysInMonth; day += 1) {
    const date = new Date(year, month, day);
    const key = toDateKey(date.getTime());
    cells.push({ type: 'day', id: key, day, key });
  }

  while (cells.length % 7 !== 0) {
    cells.push({ type: 'pad', id: `next-${cells.length}`, day: cells.length % 7 });
  }

  const rows = [];
  for (let i = 0; i < cells.length; i += 7) {
    rows.push(cells.slice(i, i + 7));
  }

  return rows;
}

function statusClass(status) {
  if (status === 'pending') return 'bg-amber-100 text-amber-800';
  if (status === 'confirmed') return 'bg-emerald-100 text-emerald-700';
  if (status === 'rejected') return 'bg-red-100 text-red-700';
  if (status === 'cancelled') return 'bg-slate-100 text-slate-700';
  if (status === 'completed') return 'bg-sky-100 text-sky-700';
  return 'bg-slate-100 text-slate-700';
}

const fieldClass =
  'h-10 w-full rounded-xl border border-slate-200 bg-white px-3 text-sm text-slate-700 outline-none transition focus:border-sky-400';

export default function BookingCalendar({
  bookings,
  rooms,
  statusFilter,
  onStatusFilterChange,
  loading,
  actionLoadingKey,
  creatingBooking,
  onBookingAction,
  onCreateBooking,
}) {
  const [viewMonth, setViewMonth] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });
  const [selectedDateKey, setSelectedDateKey] = useState(() => toDateKey(Date.now()));
  const [formState, setFormState] = useState({
    roomId: '',
    bookedForName: '',
    bookedForCompany: '',
    checkInTime: '08:00',
    checkOutTime: '09:00',
    numberOfGuests: 1,
    purpose: '',
  });

  useEffect(() => {
    if (!rooms?.length) return;
    setFormState((prev) => {
      if (prev.roomId) return prev;
      return { ...prev, roomId: rooms[0].id };
    });
  }, [rooms]);

  const groupedBookings = useMemo(() => {
    const map = {};
    bookings.forEach((booking) => {
      const key = toDateKey(booking.bookingDate);
      if (!key) return;
      if (!map[key]) map[key] = [];
      map[key].push(booking);
    });

    Object.keys(map).forEach((key) => {
      map[key].sort((a, b) => String(a.checkInTime).localeCompare(String(b.checkInTime)));
    });

    return map;
  }, [bookings]);

  const rows = useMemo(() => buildRows(viewMonth), [viewMonth]);

  const selectedBookings = useMemo(() => groupedBookings[selectedDateKey] || [], [groupedBookings, selectedDateKey]);

  const monthTitle = viewMonth.toLocaleDateString('id-ID', {
    month: 'long',
    year: 'numeric',
  });

  const canSubmitBooking = Boolean(
    formState.roomId &&
      selectedDateKey &&
      formState.checkInTime &&
      formState.checkOutTime &&
      Number(formState.numberOfGuests) > 0,
  );

  const handleCreateSubmit = async (event) => {
    event.preventDefault();
    if (!canSubmitBooking) return;

    if (formState.checkOutTime <= formState.checkInTime) {
      window.alert('Jam selesai harus lebih besar dari jam mulai.');
      return;
    }

    const bookingDate = new Date(`${selectedDateKey}T00:00:00`).getTime();
    const purpose = formState.purpose.trim();

    await onCreateBooking({
      roomId: formState.roomId,
      bookingDate,
      bookedForName: formState.bookedForName.trim() || null,
      bookedForCompany: formState.bookedForCompany.trim() || null,
      checkInTime: formState.checkInTime,
      checkOutTime: formState.checkOutTime,
      numberOfGuests: Number(formState.numberOfGuests),
      purpose: purpose || null,
    });
  };

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <header className="mb-4 flex flex-col justify-between gap-3 xl:flex-row xl:items-start">
        <div>
          <h2 className="text-xl font-semibold text-slate-900">Booking Calendar</h2>
          <p className="mt-1 text-sm text-slate-700">Monitor booking per tanggal dan lakukan approval langsung dari panel ini.</p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <select
            className={fieldClass}
            value={statusFilter}
            onChange={(event) => onStatusFilterChange(event.target.value)}
            aria-label="Filter booking status"
          >
            <option value="">Semua Status</option>
            <option value="pending">Pending</option>
            <option value="confirmed">Confirmed</option>
            <option value="rejected">Rejected</option>
            <option value="cancelled">Cancelled</option>
            <option value="completed">Completed</option>
          </select>

          <div className="inline-flex items-center gap-1 rounded-xl border border-slate-200 bg-white p-1">
            <button
              type="button"
              className="grid h-8 w-8 place-items-center rounded-lg text-sky-600 transition hover:bg-sky-50"
              onClick={() =>
                setViewMonth((current) => new Date(current.getFullYear(), current.getMonth() - 1, 1))
              }
              aria-label="Bulan sebelumnya"
            >
              <ChevronLeft size={16} />
            </button>
            <strong className="px-2 text-sm text-slate-800">{monthTitle}</strong>
            <button
              type="button"
              className="grid h-8 w-8 place-items-center rounded-lg text-sky-600 transition hover:bg-sky-50"
              onClick={() =>
                setViewMonth((current) => new Date(current.getFullYear(), current.getMonth() + 1, 1))
              }
              aria-label="Bulan berikutnya"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      </header>

      <div className="space-y-4">
        <div className="overflow-hidden rounded-2xl border border-slate-200">
          <div className="grid grid-cols-7 bg-slate-50 text-center text-[11px] font-semibold uppercase tracking-wide text-slate-500">
            {WEEKDAYS.map((day) => (
              <div key={day} className="border-b border-slate-200 py-2">
                {day}
              </div>
            ))}
          </div>

          {rows.map((week, index) => (
            <div key={`week-${index}`} className="grid grid-cols-7">
              {week.map((cell) => {
                if (cell.type === 'pad') {
                  return (
                    <button
                      key={cell.id}
                      type="button"
                      className="min-h-[84px] border border-slate-100 bg-slate-50 p-2 text-left text-sm text-slate-300"
                      disabled
                    >
                      <span>{cell.day}</span>
                    </button>
                  );
                }

                const items = groupedBookings[cell.key] || [];
                const pendingCount = items.filter((item) => item.status === 'pending').length;
                const isActive = cell.key === selectedDateKey;

                return (
                  <button
                    key={cell.id}
                    type="button"
                    className={[
                      'min-h-[84px] border border-slate-100 p-2 text-left transition',
                      isActive ? 'bg-sky-50 ring-1 ring-sky-300' : 'bg-white hover:bg-slate-50',
                    ].join(' ')}
                    onClick={() => setSelectedDateKey(cell.key)}
                  >
                    <span className="block text-sm font-semibold text-slate-800">{cell.day}</span>
                    <small className="block text-xs text-slate-600">{items.length} booking</small>
                    {pendingCount > 0 && <em className="block text-xs font-medium not-italic text-amber-700">{pendingCount} pending</em>}
                  </button>
                );
              })}
            </div>
          ))}
        </div>

        <div className="grid gap-4 xl:grid-cols-[1.05fr_0.95fr]">
          <section className="rounded-2xl border border-slate-200 bg-white p-4">
            <div className="mb-4 flex items-center justify-between gap-2">
              <div>
                <h3 className="text-lg font-semibold text-slate-900">Booking Tanggal Ini</h3>
                <p className="text-sm text-slate-600">{prettyDateFromKey(selectedDateKey)}</p>
              </div>
              {loading && <span className="text-xs text-slate-500">Sync...</span>}
            </div>

            <form className="grid gap-3" onSubmit={handleCreateSubmit}>
              <div className="grid gap-2">
                <label className="text-sm font-semibold text-slate-800">Buat booking baru</label>
                <select
                  className={fieldClass}
                  value={formState.roomId}
                  onChange={(event) => setFormState((prev) => ({ ...prev, roomId: event.target.value }))}
                  required
                >
                  <option value="">Pilih Ruangan</option>
                  {(rooms || []).map((room) => (
                    <option key={room.id} value={room.id}>
                      {room.name} - Kap. {room.maxGuests}
                    </option>
                  ))}
                </select>

                <div className="grid grid-cols-2 gap-2">
                  <input
                    className={fieldClass}
                    type="text"
                    value={formState.bookedForName}
                    onChange={(event) =>
                      setFormState((prev) => ({ ...prev, bookedForName: event.target.value }))
                    }
                    placeholder="Atas nama (opsional)"
                  />
                  <input
                    className={fieldClass}
                    type="text"
                    value={formState.bookedForCompany}
                    onChange={(event) =>
                      setFormState((prev) => ({ ...prev, bookedForCompany: event.target.value }))
                    }
                    placeholder="Instansi / perusahaan (opsional)"
                  />
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <input
                    className={fieldClass}
                    type="time"
                    value={formState.checkInTime}
                    onChange={(event) =>
                      setFormState((prev) => ({ ...prev, checkInTime: event.target.value }))
                    }
                    required
                  />
                  <input
                    className={fieldClass}
                    type="time"
                    value={formState.checkOutTime}
                    onChange={(event) =>
                      setFormState((prev) => ({ ...prev, checkOutTime: event.target.value }))
                    }
                    required
                  />
                </div>

                <input
                  className={fieldClass}
                  type="number"
                  min="1"
                  value={formState.numberOfGuests}
                  onChange={(event) =>
                    setFormState((prev) => ({ ...prev, numberOfGuests: event.target.value }))
                  }
                  placeholder="Jumlah peserta"
                  required
                />

                <input
                  className={fieldClass}
                  type="text"
                  value={formState.purpose}
                  onChange={(event) => setFormState((prev) => ({ ...prev, purpose: event.target.value }))}
                  placeholder="Tujuan rapat (opsional)"
                />
              </div>

              <button
                type="submit"
                className="h-10 w-full rounded-xl bg-gradient-to-r from-[#0099ff] to-[#0077cc] text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
                disabled={!canSubmitBooking || creatingBooking}
              >
                {creatingBooking ? 'Mengirim...' : 'Booking Tanggal Ini'}
              </button>
            </form>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-slate-50 p-3 max-h-[620px] overflow-auto">
            {selectedBookings.length === 0 ? (
              <div className="rounded-xl border border-dashed border-slate-300 bg-white p-4 text-sm text-slate-700">
                Tidak ada booking di tanggal ini.
              </div>
            ) : (
              <div className="grid gap-3">
                {selectedBookings.map((booking) => (
                  <article key={booking.id} className="rounded-2xl border border-slate-200 bg-white p-4">
                    <header className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                      <div>
                        <p className="text-sm font-semibold text-slate-900">{booking.roomName || 'Room tanpa nama'}</p>
                        <p className="text-sm text-slate-600">{booking.checkInTime} - {booking.checkOutTime}</p>
                      </div>
                      <span className={`rounded-full px-2 py-1 text-[10px] font-semibold uppercase tracking-wide ${statusClass(booking.status)}`}>
                        {booking.status}
                      </span>
                    </header>

                    <div className="space-y-2 text-sm text-slate-700">
                      <p>{booking.userName || 'Unknown User'} ({booking.userEmail || '-'})</p>
                      {booking.bookedForName ? (
                        <p>
                          For: {booking.bookedForName}
                          {booking.bookedForCompany ? ` · ${booking.bookedForCompany}` : ''}
                        </p>
                      ) : null}
                      <p>Guests: {booking.numberOfGuests}</p>
                      {booking.purpose ? (
                        <p className="rounded-xl bg-slate-50 p-3 text-sm text-slate-700">{booking.purpose}</p>
                      ) : null}
                    </div>

                    <div className="mt-4 flex flex-wrap gap-2">
                      {booking.status === 'pending' && (
                        <>
                          <button
                            type="button"
                            className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700 transition hover:bg-emerald-100 disabled:opacity-60"
                            onClick={() => onBookingAction('approve', booking)}
                            disabled={actionLoadingKey === `approve:${booking.id}`}
                          >
                            Approve
                          </button>
                          <button
                            type="button"
                            className="rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 transition hover:bg-red-100 disabled:opacity-60"
                            onClick={() => onBookingAction('reject', booking)}
                            disabled={actionLoadingKey === `reject:${booking.id}`}
                          >
                            Reject
                          </button>
                          <button
                            type="button"
                            className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:bg-slate-100 disabled:opacity-60"
                            onClick={() => onBookingAction('cancel', booking)}
                            disabled={actionLoadingKey === `cancel:${booking.id}`}
                          >
                            Cancel
                          </button>
                        </>
                      )}

                      {booking.status === 'confirmed' && (
                        <>
                          <button
                            type="button"
                            className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700 transition hover:bg-emerald-100 disabled:opacity-60"
                            onClick={() => onBookingAction('complete', booking)}
                            disabled={actionLoadingKey === `complete:${booking.id}`}
                          >
                            Complete
                          </button>
                          <button
                            type="button"
                            className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:bg-slate-100 disabled:opacity-60"
                            onClick={() => onBookingAction('cancel', booking)}
                            disabled={actionLoadingKey === `cancel:${booking.id}`}
                          >
                            Cancel
                          </button>
                        </>
                      )}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        </div>
      </div>
    </section>
  );
}
