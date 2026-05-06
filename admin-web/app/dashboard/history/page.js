'use client';

import { useCallback, useEffect, useState } from 'react';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import {
  Building2,
  CalendarDays,
  Clock,
  LayoutDashboard,
  LogOut,
  RefreshCw,
  ShieldCheck,
  Users,
} from 'lucide-react';
import BookingHistoryPanel from '@/components/BookingHistoryPanel';
import { getAdminBookings, getMe } from '@/lib/api';
import { clearSession, getStoredUser, getToken, isAdminRole, saveSession } from '@/lib/storage';

const MENU_ITEMS = [
  { key: 'overview', label: 'Overview', description: 'Ringkasan operasional', icon: LayoutDashboard, href: '/dashboard' },
  { key: 'bookings', label: 'Booking Calendar', description: 'Kelola booking harian', icon: CalendarDays, href: '/dashboard' },
  { key: 'history', label: 'Riwayat', description: 'Daftar riwayat booking', icon: Clock, href: '/dashboard/history' },
  { key: 'rooms', label: 'Rooms', description: 'Kelola ruangan', icon: Building2, href: '/dashboard' },
  { key: 'users', label: 'User Management', description: 'Atur akun dan role', icon: Users, href: '/dashboard' },
];

export default function BookingHistoryPage() {
  const router = useRouter();

  const [bootLoading, setBootLoading] = useState(true);
  const [loading, setLoading] = useState(true);
  const [token, setToken] = useState('');
  const [currentUser, setCurrentUser] = useState(() => getStoredUser());
  const [bookings, setBookings] = useState([]);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  const loadBookings = useCallback(async (activeToken) => {
    setLoading(true);
    setError('');

    try {
      const bookingData = await getAdminBookings(activeToken);
      setBookings(Array.isArray(bookingData) ? bookingData : []);
    } catch (loadError) {
      setError(loadError.message || 'Gagal memuat riwayat booking');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let ignore = false;

    async function bootstrap() {
      const activeToken = getToken();
      if (!activeToken) {
        router.replace('/login');
        return;
      }

      try {
        const profile = await getMe(activeToken);
        if (ignore) return;

        if (!profile || !isAdminRole(profile.role)) {
          clearSession();
          router.replace('/login?denied=1');
          return;
        }

        saveSession(activeToken, profile);
        setToken(activeToken);
        setCurrentUser(profile);
        await loadBookings(activeToken);
      } catch (bootstrapError) {
        if (ignore) return;
        setError(bootstrapError.message || 'Gagal memverifikasi sesi admin');
        router.replace('/login');
      } finally {
        if (!ignore) setBootLoading(false);
      }
    }

    bootstrap();

    return () => {
      ignore = true;
    };
  }, [loadBookings, router]);

  const handleLogout = () => {
    clearSession();
    router.replace('/login');
  };

  const handleRefresh = async () => {
    if (!token) return;

    setInfo('Riwayat booking diperbarui.');
    await loadBookings(token);
  };

  const navigateMenu = (key) => {
    const target = MENU_ITEMS.find((item) => item.key === key);
    if (!target) return;
    router.push(target.href);
  };

  if (bootLoading) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-3 text-slate-600">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-sky-200 border-t-sky-500" />
        <p className="text-sm">Memverifikasi sesi admin...</p>
      </main>
    );
  }

  return (
    <div className="min-h-screen bg-transparent">
      <aside className="fixed inset-y-0 left-0 z-20 hidden w-72 border-r border-slate-200 bg-[#071827] p-5 text-white shadow-2xl lg:flex lg:flex-col">
        <div className="mb-8 border-b border-white/10 pb-5">
          <Image src="/logo.png" alt="PLN NPS" width={220} height={70} className="h-auto w-auto" priority />
          <p className="mt-3 text-xs font-semibold uppercase tracking-[0.22em] text-sky-300">Smart Room Scheduler</p>
        </div>

        <nav className="grid gap-2">
          {MENU_ITEMS.map((item) => {
            const Icon = item.icon;
            const active = item.key === 'history';

            return (
              <button
                key={item.key}
                type="button"
                onClick={() => navigateMenu(item.key)}
                className={[
                  'group relative flex items-center gap-3 overflow-hidden rounded-2xl px-4 py-3 text-left transition',
                  active
                    ? 'bg-white/12 text-white shadow-lg shadow-black/20 ring-1 ring-white/10'
                    : 'text-slate-300 hover:bg-white/8 hover:text-white',
                ].join(' ')}
              >
                <span
                  className={[
                    'absolute left-0 top-0 h-full w-1 rounded-r-full transition',
                    active ? 'bg-[#FFC300]' : 'bg-transparent group-hover:bg-sky-400/60',
                  ].join(' ')}
                />
                <span
                  className={[
                    'grid h-10 w-10 shrink-0 place-items-center rounded-xl transition',
                    active ? 'bg-gradient-to-br from-[#0099ff] to-[#0077cc] text-white' : 'bg-white/10 text-sky-200',
                  ].join(' ')}
                >
                  <Icon size={18} />
                </span>
                <span className="grid gap-0.5">
                  <span className="text-sm font-semibold leading-none">{item.label}</span>
                  <span className={active ? 'text-xs text-slate-200' : 'text-xs text-slate-400'}>{item.description}</span>
                </span>
              </button>
            );
          })}
        </nav>
      </aside>

      <main className="px-4 py-4 lg:ml-72 lg:px-6">
        <header className="mb-4 rounded-3xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="mb-4 flex flex-wrap items-center gap-2 lg:hidden">
            {MENU_ITEMS.map((item) => {
              const active = item.key === 'history';
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => navigateMenu(item.key)}
                  className={[
                    'rounded-full px-3 py-1.5 text-xs font-semibold transition',
                    active ? 'bg-sky-600 text-white shadow-sm' : 'bg-slate-100 text-slate-700 hover:bg-slate-200',
                  ].join(' ')}
                >
                  {item.label}
                </button>
              );
            })}
          </div>

          <div className="flex flex-col justify-between gap-3 md:flex-row md:items-center">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-sky-600">Smart Room Scheduler</p>
              <h1 className="mt-1 text-2xl font-bold text-slate-900">Halaman Riwayat Booking</h1>
              <p className="mt-1 text-sm text-slate-800">
                Login sebagai <strong>{currentUser?.role}</strong> • {currentUser?.email}
              </p>
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                className="inline-flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-800 transition hover:border-sky-200 hover:bg-sky-50"
                onClick={handleRefresh}
              >
                <RefreshCw size={16} />
                Refresh
              </button>
              <button
                type="button"
                className="inline-flex h-10 items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-3 text-sm font-semibold text-red-700 transition hover:bg-red-100"
                onClick={handleLogout}
              >
                <LogOut size={16} />
                Logout
              </button>
            </div>
          </div>
        </header>

        {error ? (
          <div className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
        ) : null}
        {info ? (
          <div className="mb-4 flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
            <ShieldCheck size={16} />
            <span>{info}</span>
          </div>
        ) : null}

        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <BookingHistoryPanel
            bookings={bookings}
            showHeader={true}
            showFilters={true}
            showExport={true}
            previewLimit={null}
            emptyMessage={loading ? 'Memuat riwayat booking...' : 'Belum ada riwayat booking.'}
          />
        </section>
      </main>
    </div>
  );
}