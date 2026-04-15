import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { clearToken, getAdminEmail } from "../lib/auth";

const navItems = [
  { to: "/stats", label: "Stats" },
  { to: "/users", label: "Users" },
  { to: "/battles", label: "Battles" },
  { to: "/reports", label: "Reports" },
];

export function Layout() {
  const navigate = useNavigate();
  const email = getAdminEmail();

  const handleLogout = (): void => {
    clearToken();
    navigate("/login", { replace: true });
  };

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100">
      <aside className="hidden w-60 flex-col border-r border-slate-800 bg-slate-900/60 p-4 md:flex">
        <div className="mb-6 flex items-center gap-2 px-2">
          <div className="h-8 w-8 rounded-md bg-gradient-to-br from-brand-500 to-brand-700" />
          <span className="text-lg font-semibold tracking-tight">PixelMatch</span>
        </div>
        <nav className="flex flex-1 flex-col gap-1">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-brand-600/20 text-brand-200"
                    : "text-slate-300 hover:bg-slate-800 hover:text-white"
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="mt-4 px-2 text-xs text-slate-500">v1 read-only</div>
      </aside>
      <div className="flex min-h-screen flex-1 flex-col">
        <header className="flex h-14 items-center justify-between border-b border-slate-800 bg-slate-900/40 px-6">
          <div className="text-sm text-slate-400 md:hidden">PixelMatch Admin</div>
          <div className="ml-auto flex items-center gap-4">
            <span className="text-sm text-slate-300">{email ?? "admin"}</span>
            <button
              type="button"
              onClick={handleLogout}
              className="rounded-md border border-slate-700 px-3 py-1.5 text-xs font-medium text-slate-200 hover:border-slate-500 hover:bg-slate-800"
            >
              Log out
            </button>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
