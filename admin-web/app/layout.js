import { DM_Sans, Space_Grotesk } from 'next/font/google';
import './globals.css';

const dmSans = DM_Sans({ subsets: ['latin'], variable: '--font-body' });
const spaceGrotesk = Space_Grotesk({ subsets: ['latin'], variable: '--font-display' });

export const metadata = {
  title: 'Smart Room Scheduler | PLN NPS',
  description: 'Smart Room Scheduler untuk approval booking ruang, monitoring real-time, dan manajemen user PLN NPS',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={`${dmSans.variable} ${spaceGrotesk.variable}`}>{children}</body>
    </html>
  );
}
