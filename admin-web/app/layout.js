import './globals.css';

export const metadata = {
  title: 'Smart Room Scheduler | PLN NPS',
  description: 'Smart Room Scheduler untuk approval booking ruang, monitoring real-time, dan manajemen user PLN NPS',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
