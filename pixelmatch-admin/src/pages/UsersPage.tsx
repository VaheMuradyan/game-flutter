import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, keepPreviousData } from "@tanstack/react-query";
import { listUsers, type UserListItem } from "../lib/api";
import { DataTable, type Column } from "../components/DataTable";

const PAGE_SIZE = 25;

function useDebounced<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState<T>(value);
  useEffect(() => {
    const id = window.setTimeout(() => setDebounced(value), delay);
    return () => window.clearTimeout(id);
  }, [value, delay]);
  return debounced;
}

export function UsersPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounced(search, 300);
  const [cursorStack, setCursorStack] = useState<Array<string | undefined>>([undefined]);

  useEffect(() => {
    setCursorStack([undefined]);
  }, [debouncedSearch]);

  const currentCursor = cursorStack[cursorStack.length - 1];

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ["users", debouncedSearch, currentCursor ?? ""],
    queryFn: () =>
      listUsers({
        cursor: currentCursor,
        limit: PAGE_SIZE,
        q: debouncedSearch || undefined,
      }),
    placeholderData: keepPreviousData,
  });

  const columns = useMemo<Column<UserListItem>[]>(
    () => [
      {
        key: "display_name",
        header: "Display name",
        render: (u) => (
          <span className="font-medium text-white">{u.display_name || "-"}</span>
        ),
      },
      {
        key: "email",
        header: "Email",
        render: (u) => <span className="text-slate-300">{u.email_masked}</span>,
      },
      {
        key: "level",
        header: "Level",
        render: (u) => <span className="text-slate-300">{u.level}</span>,
      },
      {
        key: "league",
        header: "League",
        render: (u) => <span className="text-slate-400">{u.league}</span>,
      },
      {
        key: "created_at",
        header: "Joined",
        render: (u) => (
          <span className="text-slate-400">
            {new Date(u.created_at).toLocaleDateString()}
          </span>
        ),
      },
    ],
    [],
  );

  const rows = data?.users ?? [];
  const nextCursor = data?.next_cursor ?? null;
  const canPrev = cursorStack.length > 1;

  function handleNext() {
    if (nextCursor) {
      setCursorStack((s) => [...s, nextCursor]);
    }
  }

  function handlePrev() {
    if (canPrev) {
      setCursorStack((s) => s.slice(0, -1));
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-white">Users</h1>
          <p className="text-sm text-slate-400">Browse registered accounts.</p>
        </div>
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by name or email"
          className="w-72 rounded-md border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-100 focus:border-brand-500 focus:outline-none"
        />
      </div>

      <DataTable<UserListItem>
        columns={columns}
        rows={rows}
        loading={isLoading}
        emptyMessage="No users found."
        getRowKey={(u) => u.id}
        onRowClick={(u) => navigate(`/users/${u.id}`)}
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
