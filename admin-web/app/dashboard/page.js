'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import {
  CalendarDays,
  LayoutDashboard,
  LogOut,
  RefreshCw,
  ShieldCheck,
  Users,
} from 'lucide-react';
import BookingCalendar from '@/components/BookingCalendar';
import StatCard from '@/components/StatCard';
import UserManagement from '@/components/UserManagement';
import {
  approveBooking,
  cancelBooking,
  changeUserRole,
  completeBooking,
  createBooking,
  createUser,
  deleteUser,
  getAdminBookings,
  getMe,
  getStats,
  listRooms,
  listUsers,
  rejectBooking,
} from '@/lib/api';
import {
  clearSession,
  getStoredUser,
  getToken,
  isAdminRole,
  saveSession,
} from '@/lib/storage';

const MENU_ITEMS = [
  { key: 'overview', label: 'Overview', description: 'Ringkasan operasional', icon: LayoutDashboard },
  { key: 'bookings', label: 'Booking Calendar', description: 'Kelola booking harian', icon: CalendarDays },
  { key: 'users', label: 'User Management', description: 'Atur akun dan role', icon: Users },
];

export default function DashboardPage() {
  const router = useRouter();

  const [bootLoading, setBootLoading] = useState(true);
  const [dashboardLoading, setDashboardLoading] = useState(true);
  const [token, setToken] = useState('');
  const [currentUser, setCurrentUser] = useState(() => getStoredUser());
  const [stats, setStats] = useState({});
  const [bookings, setBookings] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [statusFilter, setStatusFilter] = useState('');
  const [actionLoadingKey, setActionLoadingKey] = useState('');
  const [creatingBooking, setCreatingBooking] = useState(false);

  const [users, setUsers] = useState([]);
  const [usersLoading, setUsersLoading] = useState(false);
  const [creatingUser, setCreatingUser] = useState(false);
  const [userActionKey, setUserActionKey] = useState('');
  const [userFilters, setUserFilters] = useState({ search: '', role: '' });

  const [activeMenu, setActiveMenu] = useState('overview');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  const loadStatsAndBookings = useCallback(
    async (activeToken) => {
      setDashboardLoading(true);
      setError('');
      try {
        const [statsData, bookingData] = await Promise.all([
          getStats(activeToken),
          getAdminBookings(activeToken, {
            status: statusFilter || undefined,
          }),
        ]);
        setStats(statsData || {});
        setBookings(Array.isArray(bookingData) ? bookingData : []);
      } catch (loadError) {
        setError(loadError.message || 'Gagal memuat dashboard');
      } finally {
        setDashboardLoading(false);
      }
    },
    [statusFilter],
  );

  const loadUsers = useCallback(async () => {
    if (!token || currentUser?.role !== 'superadmin') return;

    setUsersLoading(true);
    setError('');

    try {
      const list = await listUsers(token, {
        search: userFilters.search || undefined,
        role: userFilters.role || undefined,
      });
      setUsers(Array.isArray(list) ? list : []);
    } catch (usersError) {
      setError(usersError.message || 'Gagal memuat user');
    } finally {
      setUsersLoading(false);
    }
  }, [token, currentUser?.role, userFilters]);

  const loadRooms = useCallback(async () => {
    try {
      const roomList = await listRooms({ available: true });
      setRooms(Array.isArray(roomList) ? roomList : []);
    } catch {
      setRooms([]);
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
        const me = await getMe(activeToken);
        if (!isAdminRole(me?.role)) {
          throw new Error('Akun tidak punya akses admin');
        }

        if (ignore) return;
        saveSession(activeToken, me);
        setToken(activeToken);
        setCurrentUser(me);
      } catch {
        clearSession();
        router.replace('/login?denied=1');
      } finally {
        if (!ignore) setBootLoading(false);
      }
    }

    bootstrap();
    return () => {
      ignore = true;
    };
  }, [router]);

  useEffect(() => {
    if (!token) return;
    loadStatsAndBookings(token);
  }, [token, statusFilter, loadStatsAndBookings]);

  useEffect(() => {
    if (!token) return;
    loadRooms();
  }, [token, loadRooms]);

  useEffect(() => {
    if (!token || currentUser?.role !== 'superadmin') return;

    const timer = setTimeout(() => {
      loadUsers();
    }, 250);

    return () => clearTimeout(timer);
  }, [token, currentUser?.role, userFilters, loadUsers]);

  const statsView = useMemo(() => {
    const bookingStats = stats.bookings || {};
    const roomStats = stats.rooms || {};

    return {
      totalBookings: bookingStats.total ?? 0,
      pending: bookingStats.pending ?? 0,
      confirmed: bookingStats.confirmed ?? 0,
      rooms: roomStats.total ?? 0,
    };
  }, [stats]);

  const handleLogout = () => {
    clearSession();
    router.replace('/login');
  };

  const refreshDashboard = async () => {
    if (!token) return;
    setInfo('Data dashboard diperbarui.');
    await loadStatsAndBookings(token);
    await loadRooms();
  };

  const handleBookingAction = async (action, booking) => {
    if (!token) return;

    const key = `${action}:${booking.id}`;
    setActionLoadingKey(key);
    setError('');
    setInfo('');

    try {
      if (action === 'approve') {
        await approveBooking(token, booking.id, { note: 'approved from admin web' });
        setInfo('Booking berhasil di-approve.');
      }

      if (action === 'reject') {
        const reason = window.prompt('Masukkan alasan reject (minimal 5 karakter):', '');
        if (!reason) {
          return;
        }
        await rejectBooking(token, booking.id, reason);
        setInfo('Booking berhasil di-reject.');
      }

      if (action === 'complete') {
        await completeBooking(token, booking.id);
        setInfo('Booking ditandai completed.');
      }

      if (action === 'cancel') {
        const confirmed = window.confirm('Batalkan booking ini?');
        if (!confirmed) return;
        await cancelBooking(token, booking.id);
        setInfo('Booking berhasil dibatalkan.');
      }

      await loadStatsAndBookings(token);
    } catch (bookingError) {
      setError(bookingError.message || 'Aksi booking gagal dijalankan');
    } finally {
      setActionLoadingKey('');
    }
  };

  const handleCreateBooking = async (payload) => {
    if (!token) return;

    setCreatingBooking(true);
    setError('');
    setInfo('');

    try {
      await createBooking(token, payload);
      setInfo('Booking berhasil diajukan dan menunggu approval admin.');
      await loadStatsAndBookings(token);
    } catch (createError) {
      setError(createError.message || 'Gagal membuat booking');
    } finally {
      setCreatingBooking(false);
    }
  };

  const handleCreateUser = async (payload) => {
    if (!token) return;

    setCreatingUser(true);
    setError('');
    setInfo('');

    try {
      await createUser(token, payload);
      setInfo('User baru berhasil dibuat.');
      await loadUsers();
    } catch (createError) {
      setError(createError.message || 'Gagal membuat user baru');
    } finally {
      setCreatingUser(false);
    }
  };

  const handleChangeRole = async (user, nextRole) => {
    if (!token || user.role === nextRole) return;

    setUserActionKey(`role:${user.id}`);
    setError('');
    setInfo('');

    try {
      await changeUserRole(token, user.id, nextRole);
      setInfo(`Role ${user.email} berubah ke ${nextRole}.`);
      await loadUsers();
    } catch (changeError) {
      setError(changeError.message || 'Gagal mengubah role user');
    } finally {
      setUserActionKey('');
    }
  };

  const handleDeleteUser = async (user) => {
    if (!token) return;

    const confirmed = window.confirm(`Hapus user ${user.email}?`);
    if (!confirmed) return;

    setUserActionKey(`delete:${user.id}`);
    setError('');
    setInfo('');

    try {
      await deleteUser(token, user.id);
      setInfo(`User ${user.email} berhasil dihapus.`);
      await loadUsers();
    } catch (deleteError) {
      setError(deleteError.message || 'Gagal menghapus user');
    } finally {
      setUserActionKey('');
    }
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
            const active = activeMenu === item.key;
            return (
              <button
                key={item.key}
                type="button"
                onClick={() => setActiveMenu(item.key)}
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
                <span className={[
                  'grid h-10 w-10 shrink-0 place-items-center rounded-xl transition',
                  active ? 'bg-gradient-to-br from-[#0099ff] to-[#0077cc] text-white' : 'bg-white/10 text-sky-200',
                ].join(' ')}>
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
              const active = activeMenu === item.key;
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setActiveMenu(item.key)}
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
              <h1 className="mt-1 text-2xl font-bold text-slate-900">Booking & User Management</h1>
              <p className="mt-1 text-sm text-slate-800">
                Login sebagai <strong>{currentUser?.role}</strong> • {currentUser?.email}
              </p>
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                className="inline-flex h-10 items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 text-sm font-semibold text-slate-800 transition hover:border-sky-200 hover:bg-sky-50"
                onClick={refreshDashboard}
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

        {activeMenu === 'overview' && (
          <section className="grid gap-4">
            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
              <StatCard label="Total Bookings" value={statsView.totalBookings} tone="neutral" />
              <StatCard label="Pending Approval" value={statsView.pending} tone="warning" />
              <StatCard label="Confirmed" value={statsView.confirmed} tone="positive" />
              <StatCard label="Total Rooms" value={statsView.rooms} tone="accent" />
            </div>

            <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="text-xl font-semibold text-slate-900">Ringkasan Operasional</h2>
              <p className="mt-2 text-sm leading-relaxed text-slate-800">
                Gunakan menu sidebar untuk pindah ke kalender booking atau manajemen user. Dari menu Booking Calendar,
                admin dapat klik tanggal lalu langsung membuat booking baru, approve/reject booking pending,
                atau menyelesaikan booking confirmed.
              </p>
              <div className="mt-4 inline-flex rounded-lg bg-sky-50 px-3 py-2 text-xs font-semibold text-sky-700">
                {dashboardLoading ? 'Menyinkronkan data...' : `Data terakhir tersinkron: ${new Date().toLocaleTimeString('id-ID')}`}
              </div>
            </div>
          </section>
        )}

        {activeMenu === 'bookings' && (
          <BookingCalendar
            bookings={bookings}
            rooms={rooms}
            statusFilter={statusFilter}
            onStatusFilterChange={setStatusFilter}
            loading={dashboardLoading}
            actionLoadingKey={actionLoadingKey}
            creatingBooking={creatingBooking}
            onBookingAction={handleBookingAction}
            onCreateBooking={handleCreateBooking}
          />
        )}

        {activeMenu === 'users' && (
          <UserManagement
            canManage={currentUser?.role === 'superadmin'}
            users={users}
            loading={usersLoading}
            filters={userFilters}
            onFiltersChange={setUserFilters}
            onCreateUser={handleCreateUser}
            onChangeRole={handleChangeRole}
            onDeleteUser={handleDeleteUser}
            actionBusyKey={userActionKey}
            creating={creatingUser}
            currentUserId={currentUser?.id}
          />
        )}
      </main>
    </div>
  );
}
