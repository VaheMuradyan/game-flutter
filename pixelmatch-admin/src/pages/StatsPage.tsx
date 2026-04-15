import { useQuery } from "@tanstack/react-query";
import { getStats } from "../lib/api";
import { StatCard } from "../components/StatCard";

function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return "0s";
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  if (m === 0) return `${s}s`;
  return `${m}m ${s}s`;
}

export function StatsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["stats"],
    queryFn: getStats,
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-white">Overview</h1>
        <p className="text-sm text-slate-400">Live snapshot of the PixelMatch service.</p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Total users"
          value={data ? data.total_users.toLocaleString() : "-"}
          loading={isLoading}
        />
        <StatCard
          label="Matches today"
          value={data ? data.matches_today.toLocaleString() : "-"}
          loading={isLoading}
        />
        <StatCard
          label="Battles today"
          value={data ? data.battles_today.toLocaleString() : "-"}
          loading={isLoading}
        />
        <StatCard
          label="Avg battle duration"
          value={data ? formatDuration(data.avg_battle_duration) : "-"}
          loading={isLoading}
        />
      </div>
    </div>
  );
}
