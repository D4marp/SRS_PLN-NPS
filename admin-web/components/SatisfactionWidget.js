export default function SatisfactionWidget({ stats }) {
  const satisfied = Number(stats?.feedbackSatisfied || stats?.satisfied || 0);
  const unsatisfied = Number(stats?.feedbackUnsatisfied || stats?.unsatisfied || 0);
  const total = Number(stats?.feedbackTotal || stats?.total || satisfied + unsatisfied);
  const rate = total > 0 ? Number(stats?.feedbackRate ?? stats?.satisfactionRate ?? (satisfied / total) * 100) : 0;

  const pieStyle = {
    background: `conic-gradient(#10b981 0 ${rate}%, #ef4444 ${rate}% 100%)`,
  };

  return (
    <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-sky-600">Feedback</p>
          <h2 className="text-xl font-semibold text-slate-900">Satisfaction Rate</h2>
        </div>
        <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600">
          {rate.toFixed(0)}% puas
        </span>
      </div>

      <div className="mt-5 grid gap-5 md:grid-cols-[160px_1fr] md:items-center">
        <div className="mx-auto flex h-36 w-36 items-center justify-center rounded-full bg-slate-50">
          <div className="relative h-28 w-28 rounded-full p-3" style={pieStyle}>
            <div className="absolute inset-[10px] grid place-items-center rounded-full bg-white shadow-sm">
              <div className="text-center">
                <div className="text-2xl font-bold text-slate-900">{rate.toFixed(0)}%</div>
                <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500">Puas</div>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <div className="mb-2 flex items-center justify-between text-sm font-medium text-slate-700">
              <span>Puas</span>
              <span>{satisfied}</span>
            </div>
            <div className="h-3 rounded-full bg-emerald-100">
              <div className="h-3 rounded-full bg-emerald-500 transition-all" style={{ width: `${total > 0 ? (satisfied / total) * 100 : 0}%` }} />
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-center justify-between text-sm font-medium text-slate-700">
              <span>Kurang Puas</span>
              <span>{unsatisfied}</span>
            </div>
            <div className="h-3 rounded-full bg-red-100">
              <div className="h-3 rounded-full bg-red-500 transition-all" style={{ width: `${total > 0 ? (unsatisfied / total) * 100 : 0}%` }} />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-3">
              <div className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Total puas</div>
              <div className="mt-1 text-2xl font-bold text-emerald-900">{satisfied}</div>
            </div>
            <div className="rounded-xl border border-red-200 bg-red-50 p-3">
              <div className="text-xs font-semibold uppercase tracking-wide text-red-700">Total kurang</div>
              <div className="mt-1 text-2xl font-bold text-red-900">{unsatisfied}</div>
            </div>
          </div>
        </div>
      </div>
    </article>
  );
}