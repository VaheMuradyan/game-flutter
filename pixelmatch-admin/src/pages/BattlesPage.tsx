import { useMemo, useState } from "react";
import { useQuery, keepPreviousData } from "@tanstack/react-query";
import { listBattles, type BattleListItem } from "../lib/api";
import { DataTable, type Column } from "../components/DataTable";

const PAGE_SIZE = 25;

export function BattlesPage() {
  const [cursorStack, setCursorStack] = useState<Array<string | undefined>>([undefined]);
  const currentCursor = cursorStack[cursorStack.length - 1];

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ["battles", currentCursor ?? ""],
    queryFn: () => listBattles({ cursor: currentCursor, limit: PAGE_SIZE }),
    placeholderData: keepPreviousData,
  });

  const columns = useMemo<Column<BattleListItem>[]>(
    () => [
      {
        key: "started_at",
        header: "Started",
        render: (b) => (
          <span className="text-slate-400">
            {new Date(b.started_at).toLocaleString()}
          </span>
        ),
      },
      {
        key: "p1",
        header: "Player 1",
        render: (b) => <span className="text-slate-200">{b.p1_display_name}</span>,
      },
      {
        key: "p2",
        header: "Player 2",
        render: (b) => <span className="text-slate-200">{b.p2_display_name}</span>,
      },
      {
        key: "winner",
        header: "Winner",
        render: (b) => (
          <span className="text-slate-300">
            {b.winner_display_name ?? "Draw"}
          </span>
        ),
      },
      {
        key: "duration",
        header: "Duration",
        render: (b) => (
          <span className="text-slate-400">{b.duration_seconds}s</span>
        ),
      },
    ],
    [],
  );

  const rows = data?.battles ?? [];
  const nextCursor = data?.next_cursor ?? null;
  const canPrev = cursorStack.length > 1;

  function handleNext() {
    if (nextCursor) setCursorStack((s) => [...s, nextCursor]);
  }
  function handlePrev() {
    if (canPrev) setCursorStack((s) => s.slice(0, -1));
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold text-white">Battles</h1>
        <p className="text-sm text-slate-400">Recent matches across the service.</p>
      </div>

      <DataTable<BattleListItem>
        columns={columns}
        rows={rows}
        loading={isLoading}
        emptyMessage="No battles yet."
        getRowKey={(b) => b.id}
      />

      <div className="flex items-center justify-between text-sm text-slate-400">
        <div>{isFetching ? "Loading..." : `${rows.length} shown`}</div>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={handlePrev}
            disabled={!canPrev}
            className="rounded-md border border-slate-700 px-3 py-1.5 text-xs font-medium text-slate-200 hover:border-slate-500 hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Previous
          </button>
          <button
            type="button"
            onClick={handleNext}
            disabled={!nextCursor}
            className="rounded-md border border-slate-700 px-3 py-1.5 text-xs font-medium text-slate-200 hover:border-slate-500 hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
