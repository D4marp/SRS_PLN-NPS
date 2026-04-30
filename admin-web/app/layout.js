import { Plus_Jakarta_Sans } from 'next/font/google';
import './globals.css';

const plusJakarta = Plus_Jakarta_Sans({ subsets: ['latin'], variable: '--font-body' });

export const metadata = {
  title: 'Smart Room Scheduler | PLN NPS',
  description: 'Smart Room Scheduler untuk approval booking ruang, monitoring real-time, dan manajemen user PLN NPS',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={`${plusJakarta.variable}`}>{children}</body>
    </html>
  );
}
