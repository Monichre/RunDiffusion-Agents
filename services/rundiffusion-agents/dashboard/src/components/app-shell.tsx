import type { ReactNode } from "react";
import { ChevronRight, CircleUserRound, LayoutGrid, Wrench } from "lucide-react";

import { cn } from "../lib/utils";

const BRAND_LOGO_PATH = `${import.meta.env.BASE_URL}rundiffusion-agents-logo.png`;

type NavigationItem = {
  id: string;
  label: string;
  description: string;
  enabled?: boolean;
};

type AppShellProps = {
  brandName: string;
  tenantLabel: string;
  titleSuffix: string;
  title: string;
  subtitle: string;
  tools: NavigationItem[];
  utilities: NavigationItem[];
  selectedId: string;
  onSelect: (id: string) => void;
  children: ReactNode;
};

function NavigationSection({
  icon,
  label,
  items,
  selectedId,
  onSelect,
  compact = false,
}: {
  icon: ReactNode;
  label: string;
  items: NavigationItem[];
  selectedId: string;
  onSelect: (id: string) => void;
  compact?: boolean;
}) {
  return (
    <section className="space-y-3">
      <div className="flex items-center gap-2 px-2 text-xs font-semibold uppercase tracking-[0.22em] text-zinc-500">
        {icon}
        <span>{label}</span>
      </div>
      <div className="space-y-1.5">
        {items.map((item) => {
          const isSelected = item.id === selectedId;
          const isDisabled = item.enabled === false;

          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onSelect(item.id)}
              className={cn(
                "flex w-full cursor-pointer items-start justify-between gap-3 rounded-2xl border px-3 text-left transition-colors",
                compact ? "py-2.5" : "py-3",
                isSelected
                  ? "border-cyan-400/30 bg-cyan-400/10 text-zinc-50"
                  : "border-transparent bg-zinc-950/30 text-zinc-300 hover:border-zinc-800 hover:bg-zinc-900/70",
              )}
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{item.label}</div>
                {!compact ? (
                  <div className="mt-1 text-xs leading-5 text-zinc-500">{item.description}</div>
                ) : null}
              </div>
              <div className="mt-0.5 flex shrink-0 items-center gap-2">
                {isDisabled ? (
                  <span className="rounded-full border border-zinc-800 px-2 py-0.5 text-[10px] uppercase tracking-[0.2em] text-zinc-500">
                    Off
                  </span>
                ) : null}
                <ChevronRight className="h-4 w-4 text-zinc-600" />
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}

export function AppShell({
  brandName,
  tenantLabel,
  titleSuffix,
  title,
  subtitle,
  tools,
  utilities,
  selectedId,
  onSelect,
  children,
}: AppShellProps) {
  return (
    <div className="h-screen overflow-hidden bg-[radial-gradient(circle_at_top,_rgba(34,211,238,0.18),_transparent_28%),linear-gradient(180deg,_#111827_0%,_#09090b_38%,_#020617_100%)] text-zinc-50">
      <div className="mx-auto flex h-full w-full max-w-[1800px] gap-6 px-4 py-4 lg:px-6">
        <aside className="flex h-full w-full max-w-sm min-h-0 flex-col rounded-[28px] border border-zinc-800/80 bg-zinc-950/70 p-4 shadow-[0_24px_80px_-36px_rgba(0,0,0,0.85)] backdrop-blur lg:max-w-[320px]">
          <div className="rounded-3xl border border-zinc-800 bg-zinc-950/80 p-4">
            <div className="flex items-center gap-3">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2 text-xs font-semibold uppercase tracking-[0.24em]">
                  <span className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-cyan-400/35 bg-cyan-400/12 text-cyan-100">
                    <CircleUserRound className="h-4 w-4" />
                  </span>
                  <span className="text-zinc-500">{tenantLabel}</span>
                </div>
              </div>
            </div>
            <h1 className="mt-3 text-2xl font-semibold tracking-tight">{title}</h1>
            <p className="mt-2 text-sm leading-6 text-zinc-400">{subtitle}</p>
            <div className="mt-3 flex items-center gap-2 text-xs uppercase tracking-[0.22em] text-zinc-500">
              <img src={BRAND_LOGO_PATH} alt="" aria-hidden="true" className="h-4 w-4 shrink-0" />
              <span>{titleSuffix}</span>
            </div>
          </div>

          <div className="mt-6 min-h-0 flex-1 space-y-6 overflow-y-auto pr-1">
            <NavigationSection
              icon={<LayoutGrid className="h-4 w-4" />}
              label="Apps"
              items={tools}
              selectedId={selectedId}
              onSelect={onSelect}
            />
          </div>

          <div className="mt-4 border-t border-zinc-900 pt-4">
            <NavigationSection
              icon={<Wrench className="h-4 w-4" />}
              label="Utilities"
              items={utilities}
              selectedId={selectedId}
              onSelect={onSelect}
              compact
            />

            <div className="mt-4 border-t border-zinc-900/80 pt-4">
              <a
                href="https://www.rundiffusion.com?utm_source=agents-dashboard&utm_medium=product&utm_campaign=run-diffusion-agents&utm_content=sidebar-brand-link"
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-2 text-sm font-medium text-zinc-300 transition-colors hover:text-zinc-50"
              >
                <img src={BRAND_LOGO_PATH} alt="" aria-hidden="true" className="h-5 w-5 shrink-0" />
                <span>RunDiffusion.com Agents</span>
              </a>
            </div>
          </div>
        </aside>

        <main className="min-w-0 min-h-0 flex-1 overflow-hidden">{children}</main>
      </div>
    </div>
  );
}
