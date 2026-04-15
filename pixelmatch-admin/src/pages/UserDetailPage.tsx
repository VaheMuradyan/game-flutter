import { useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router-dom";
import { getUser, type UserBattleSummary } from "../lib/api";
import { DataTable, type Column } from "../components/DataTable";

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wider text-slate-500">{label}</div>
      <div className="mt-1 text-slate-200">{value}</div>
    </div>
  );
}

export function UserDetailPage() {
  const { uid = "" } = useParams<{ uid: string }>();
  const { data, isLoading, isError } = useQuery({
    queryKey: ["user", uid],
    queryFn: () => getUser(uid),
    enabled: Boolean(uid),
  });

  const columns: Column<UserBattleSummary>[] = [
    {
      key: "ended_at",
      header: "When",
      render: (b) => (
        <span className="text-slate-400">
          {b.ended_at ? new Date(b.ended_at).toLocaleString() : "-"}
        </span>
      ),
    },
    {
      key: "opponent",
      header: "Opponent",
      render: (b) => <span className="text-slate-200">{b.opponent_display_name}</span>,
    },
    {
      key: "result",
      header: "Result",
      render: (b) => {
        const r = b.result.toLowerCase();
        const cls =
          r === "win"
            ? "text-emerald-400"
            : r === "loss"
              ? "text-red-400"
              : "text-slate-400";
        return <span className={cls}>{b.result}</span>;
      },
    },
    {
      key: "duration",
      header: "Duration",
      render: (b) => <span className="text-slate-400">{b.duration_seconds}s</span>,
    },
  ];

  if (isError) {
    return (
      <div className="space-y-4">
        <Link to="/users" className="text-sm text-slate-400 hover:text-slate-200">
          Back to users
        </Link>
        <div className="text-red-400">User not found.</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Link to="/users" className="text-sm text-slate-400 hover:text-slate-200">
        Back to users
      </Link>

      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
        {isLoading || !data ? (
          <div className="space-y-3">
            <div className="h-7 w-48 animate-pulse rounded bg-slate-800" />
            <div className="h-4 w-64 animate-pulse rounded bg-slate-800" />
          </div>
        ) : (
          <>
            <div className="text-2xl font-semibold text-white">
              {data.display_name || "(no name)"}
            </div>
            <div className="mt-1 text-sm text-slate-400">{data.email}</div>
            <div className="mt-6 grid grid-cols-2 gap-4 text-sm md:grid-cols-4">
              <Field label="ID" value={data.id} />
              <Field label="Level" value={String(data.level)} />
              <Field label="XP" value={String(data.xp)} />
              <Field label="League" value={data.league} />
              <Field label="Total matches" value={String(data.total_matches)} />
              <Field label="Total battles" value={String(data.total_battles)} />
              <Field
                label="Joined"
                value={new Date(data.created_at).toLocaleDateString()}
              />
              <Field
                label="Last active"
                value={
                  data.last_active_at
                    ? new Date(data.last_active_at).toLocaleString()
                    : "-"
                }
              />
            </div>
          </>
        )}
      </div>

      <section className="space-y-3">
        <h2 className="text-sm uppercase tracking-wider text-slate-500">Recent battles</h2>
        <DataTable<UserBattleSummary>
          columns={columns}
          rows={data?.recent_battles ?? []}
          loading={isLoading}
          emptyMessage="No battles on record."
          getRowKey={(b) => b.id}
        />
      </section>
    </div>
  );
}
