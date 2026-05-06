'use client';

import { useMemo, useState } from 'react';
import { Download, ExternalLink } from 'lucide-react';

const fieldClass =
  'h-10 w-full rounded-xl border border-slate-200 bg-white px-3 text-sm text-slate-700 outline-none transition focus:border-sky-400';

function formatBookingDate(value) {
  const numericValue = Number(value || 0);
  if (!numericValue) return '-';

  const date = new Date(numericValue);
  if (Number.isNaN(date.getTime())) return '-';

  return date.toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

export default function BookingHistoryPanel({
  bookings,
  title = 'Riwayat Booking',
  subtitle = 'Filter riwayat booking berdasarkan status dan rentang tanggal, lalu export ke Excel.',
  showHeader = true,
  showFilters = true,
  showExport = true,
  previewLimit = null,
  emptyMessage = 'Belum ada riwayat booking.',
  onOpenPage,
}) {
  const [statusFilter, setStatusFilter] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [feedback, setFeedback] = useState('');
  const [exporting, setExporting] = useState(false);

  const filteredBookings = useMemo(() => {
    const source = Array.isArray(bookings) ? bookings : [];
    let filtered = [...source];

    if (statusFilter) {
      filtered = filtered.filter((booking) => booking.status === statusFilter);
    }

    if (dateFrom) {
      const fromTime = new Date(`${dateFrom}T00:00:00`).getTime();
      filtered = filtered.filter((booking) => Number(booking.bookingDate || 0) >= fromTime);
    }

    if (dateTo) {
      const toTime = new Date(`${dateTo}T23:59:59`).getTime();
      filtered = filtered.filter((booking) => Number(booking.bookingDate || 0) <= toTime);
    }

    return filtered.sort((left, right) => Number(right.bookingDate || 0) - Number(left.bookingDate || 0));
  }, [bookings, statusFilter, dateFrom, dateTo]);

  const visibleBookings = useMemo(() => {
    if (typeof previewLimit === 'number') {
      return filteredBookings.slice(0, previewLimit);
    }

    return filteredBookings;
  }, [filteredBookings, previewLimit]);

  const handleExport = async () => {
    try {
      setExporting(true);
      setFeedback('');

      const { writeFile, utils } = await import('xlsx');
      const exportData = filteredBookings.map((booking) => ({
        Ruangan: booking.roomName || '-',
        'Tanggal Booking': formatBookingDate(booking.bookingDate),
        'Jam Check-in': booking.checkInTime || '-',
        'Jam Check-out': booking.checkOutTime || '-',
        Status: booking.status || '-',
        Pengguna: booking.userName || '-',
        Email: booking.userEmail || '-',
        Untuk: booking.bookedForName || '-',
        Instansi: booking.bookedForCompany || '-',
        'Jumlah Tamu': booking.numberOfGuests || '-',
        Tujuan: booking.purpose || '-',
      }));

      const worksheet = utils.json_to_sheet(exportData);
      const workbook = utils.book_new();
      utils.book_append_sheet(workbook, worksheet, 'Booking History');

      const timestamp = new Date().toISOString().slice(0, 10);
      writeFile(workbook, `booking-history-${timestamp}.xlsx`);
      setFeedback('Data berhasil diexport ke Excel.');
    } catch (error) {
      setFeedback(error.message || 'Gagal export data ke Excel');
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="space-y-4">
      {showHeader ? (
        <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-start">
          <div>
            <h2 className="text-xl font-semibold text-slate-900">{title}</h2>
            <p className="mt-1 text-sm text-slate-700">{subtitle}</p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
              {filteredBookings.length} item
            </span>
            {onOpenPage ? (
              <button
                type="button"
                className="inline-flex h-10 items-center gap-2 rounded-xl border border-sky-200 bg-sky-50 px-3 text-sm font-semibold text-sky-700 transition hover:bg-sky-100"
                onClick={onOpenPage}
              >
                <ExternalLink size={16} />
                Buka Halaman
              </button>
            ) : null}
          </div>
        </div>
      ) : null}

      {showFilters ? (
        <div className="grid gap-3 sm:grid-cols-3">
          <select
            className={fieldClass}
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
          >
            <option value="">Semua Status</option>
            <option value="pending">Pending</option>
            <option value="confirmed">Confirmed</option>
            <option value="rejected">Rejected</option>
            <option value="cancelled">Cancelled</option>
            <option value="completed">Completed</option>
          </select>

          <input
            type="date"
            className={fieldClass}
            value={dateFrom}
            onChange={(event) => setDateFrom(event.target.value)}
          />

          <input
            type="date"
            className={fieldClass}
            value={dateTo}
            onChange={(event) => setDateTo(event.target.value)}
          />
        </div>
      ) : null}

      {showExport || previewLimit ? (
        <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
          <p className="text-sm text-slate-700">
            {showFilters
              ? 'Filter riwayat booking lalu export hasilnya ke Excel.'
              : 'Preview riwayat booking terbaru yang tampil di dashboard.'}
          </p>

          {showExport ? (
            <button
              type="button"
              className="inline-flex h-10 items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-3 text-sm font-semibold text-emerald-700 transition hover:bg-emerald-100 disabled:cursor-not-allowed disabled:opacity-60"
              onClick={handleExport}
              disabled={exporting || filteredBookings.length === 0}
            >
              <Download size={16} />
              {exporting ? 'Mengekspor...' : 'Export Excel'}
            </button>
          ) : null}
        </div>
      ) : null}

      {feedback ? (
        <div className="rounded-xl border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-700">{feedback}</div>
      ) : null}

      {visibleBookings.length === 0 ? (
        <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50 p-4 text-sm text-slate-600">
          {emptyMessage}
        </div>
      ) : (
        <div className={previewLimit ? 'space-y-3 max-h-[420px] overflow-auto pr-1' : 'space-y-3 max-h-[65vh] overflow-auto pr-1'}>
          {visibleBookings.map((booking) => (
            <article key={booking.id} className="rounded-xl border border-slate-200 bg-slate-50 p-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-sm font-semibold text-slate-900">{booking.roomName || 'Room tanpa nama'}</p>
                  <p className="text-xs text-slate-600">
                    {formatBookingDate(booking.bookingDate)} • {booking.checkInTime} - {booking.checkOutTime}
                  </p>
                </div>
                <span className="rounded-full bg-white px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-slate-600">
                  {booking.status}
                </span>
              </div>
              <p className="mt-2 text-xs text-slate-700">
                {booking.userName || 'Unknown User'} • Guests: {booking.numberOfGuests}
              </p>
              {booking.actualDurationMinutes != null || booking.actualCheckInTime || booking.actualCheckOutTime ? (
                <p className="mt-1 text-[11px] text-slate-500">
                  Aktual: {booking.actualCheckInTime || '-'} - {booking.actualCheckOutTime || '-'}
                  {booking.actualDurationMinutes != null ? ` • ${booking.actualDurationMinutes} menit` : ''}
                </p>
              ) : null}
              {booking.purpose ? <p className="mt-2 line-clamp-2 text-xs text-slate-600">{booking.purpose}</p> : null}
              
              {booking.feedback ? (
                <div className="mt-3 space-y-2 rounded-lg border border-slate-200 bg-white p-2">
                  <div className="flex items-center gap-2">
                    <span className="text-lg">{booking.feedback.satisfactionLevel === 'satisfied' ? '😊' : '😞'}</span>
                    <span className="text-xs font-semibold text-slate-700">
                      {booking.feedback.satisfactionLevel === 'satisfied' ? 'Puas' : 'Kurang Puas'}
                    </span>
                  </div>
                  <p className="line-clamp-2 text-xs text-slate-600">{booking.feedback.reason}</p>
                </div>
              ) : null}
            </article>
          ))}
        </div>
      )}
    </div>
  );
}