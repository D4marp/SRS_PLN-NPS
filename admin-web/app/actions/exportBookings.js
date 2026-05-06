'use server';

import { writeFile, utils } from 'xlsx';
import { writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

export async function exportHistoryToExcelServer(bookings) {
  try {
    const exportData = bookings.map((booking) => ({
      'Ruangan': booking.roomName || '-',
      'Tanggal Booking': booking.bookingDate
        ? new Date(booking.bookingDate).toLocaleDateString('id-ID')
        : '-',
      'Jam Check-in': booking.checkInTime || '-',
      'Jam Check-out': booking.checkOutTime || '-',
      'Status': booking.status || '-',
      'Pengguna': booking.userName || '-',
      'Email': booking.userEmail || '-',
      'Untuk': booking.bookedForName || '-',
      'Instansi': booking.bookedForCompany || '-',
      'Jumlah Tamu': booking.numberOfGuests || '-',
      'Tujuan': booking.purpose || '-',
    }));

    const ws = utils.json_to_sheet(exportData);
    const wb = utils.book_new();
    utils.book_append_sheet(wb, ws, 'Booking History');

    // Create temp file
    const timestamp = new Date().toISOString().slice(0, 10);
    const filename = `booking-history-${timestamp}.xlsx`;
    const filepath = join(tmpdir(), filename);
    
    // Write file to temp and get buffer
    writeFileSync(filepath, Buffer.from(wb));
    
    return {
      success: true,
      filename: filename,
      message: 'Data berhasil diexport ke Excel.',
    };
  } catch (error) {
    return {
      success: false,
      error: error.message || 'Gagal export data ke Excel',
    };
  }
}
