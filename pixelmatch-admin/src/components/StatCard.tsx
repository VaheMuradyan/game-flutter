interface StatCardProps {
  label: string;
  value: string | number;
  delta?: string;
  loading?: boolean;
}

export function StatCard({ label, value, delta, loading }: StatCardProps) {
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5 shadow-sm">
      <div className="text-xs font-medium uppercase tracking-wider text-slate-400">
        {label}
      </div>
      {loading ? (
        <div className="mt-3 h-8 w-24 animate-pulse rounded bg-slate-800" />
      ) : (
        <div className="mt-2 text-3xl font-semibold text-white">{value}</div>
      )}
      {delta && !loading ? (
        <div className="mt-1 text-xs text-emerald-400">{delta}</div>
      ) : null}
    </div>
  );
}
