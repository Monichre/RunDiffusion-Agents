import { ArrowUpRight, TriangleAlert, Wrench } from "lucide-react";

import { ToolHelpDialog } from "./tool-help-dialog";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "./ui/card";

export type ToolHelpCommand = {
  label: string;
  command: string;
  description?: string;
};

export type ToolHelpSection = {
  title: string;
  description?: string;
  tips?: string[];
  commands?: ToolHelpCommand[];
  directories?: string[];
};

export type ToolHelpDefinition = {
  title: string;
  description: string;
  sections: ToolHelpSection[];
};

export type ToolDefinition = {
  id: string;
  label: string;
  tabTitle?: string;
  description: string;
  path: string;
  enabled: boolean;
  supportsRuntimeActions?: boolean;
  help?: ToolHelpDefinition | null;
};

export type ToolRuntimeStatus = {
  toolId: string;
  supported: boolean;
  enabled: boolean;
  canRelaunch: boolean;
  phase: string;
  mode: string;
  summary: string;
  detail: string;
  updatedAt: string | null;
};

export type ToolActionResult = {
  kind: "success" | "error";
  title: string;
  detail?: string;
} | null;

type ToolFrameProps = {
  brandName: string;
  tool: ToolDefinition;
  openclawAccessMode: string;
  busyActionId?: string | null;
  onRestartOpenClaw?: () => Promise<void> | void;
  runtimeStatus?: ToolRuntimeStatus | null;
  actionResult?: ToolActionResult;
  onRelaunchTool?: (toolId: string) => Promise<void> | void;
};

function runtimeBadgeVariant(phase: string): "success" | "warning" | "muted" {
  if (phase === "running") return "success";
  if (phase === "starting") return "warning";
  return "muted";
}

function formatRuntimeTimestamp(value: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "medium",
    timeZone: "UTC",
  }).format(date);
}

export function ToolFrame({
  brandName,
  tool,
  openclawAccessMode,
  busyActionId,
  onRestartOpenClaw,
  runtimeStatus,
  actionResult,
  onRelaunchTool,
}: ToolFrameProps) {
  const isOpenClaw = tool.id === "openclaw";
  const isRestartingOpenClaw = busyActionId === "restart-openclaw";
  const isRelaunchingTool = busyActionId === `relaunch:${tool.id}`;
  const showRuntimeActions = Boolean(tool.supportsRuntimeActions && runtimeStatus?.supported);

  return (
    <div className="flex h-full min-h-0 flex-col gap-5">
      <Card>
        <CardHeader className="gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-3">
              <Badge variant={tool.enabled ? "success" : "muted"}>{tool.enabled ? "Available" : "Disabled"}</Badge>
              {isOpenClaw ? (
                <Badge variant="warning">{openclawAccessMode === "native" ? "Native auth" : "Proxy auth"}</Badge>
              ) : null}
              {showRuntimeActions ? (
                <Badge variant={runtimeBadgeVariant(runtimeStatus.phase)}>{runtimeStatus.summary}</Badge>
              ) : null}
            </div>
            <div>
              <CardTitle className="text-2xl">{tool.label}</CardTitle>
              <CardDescription className="mt-2 max-w-3xl">{tool.description}</CardDescription>
              {isOpenClaw ? (
                <CardDescription className="mt-3 max-w-4xl text-zinc-300">
                  OpenClaw stays on its existing native auth flow here. If the embedded view asks you to
                  connect or pair a device, that is expected. The other operator tools share the
                  dashboard&apos;s Basic Auth more directly than OpenClaw does.
                </CardDescription>
              ) : null}
              {showRuntimeActions ? (
                <CardDescription className="mt-3 max-w-4xl text-zinc-300">
                  {runtimeStatus.detail}
                  {runtimeStatus.updatedAt ? ` Last update: ${formatRuntimeTimestamp(runtimeStatus.updatedAt)} UTC.` : ""}
                </CardDescription>
              ) : null}
            </div>
          </div>

          <div className="flex shrink-0 flex-wrap gap-3">
            {tool.help ? <ToolHelpDialog brandName={brandName} tool={tool} /> : null}
            {isOpenClaw ? (
              <Button
                variant="destructive"
                onClick={() => void onRestartOpenClaw?.()}
                disabled={isRestartingOpenClaw}
              >
                <Wrench className="h-4 w-4" />
                Restart OpenClaw
              </Button>
            ) : null}
            {showRuntimeActions ? (
              <Button variant="secondary" onClick={() => void onRelaunchTool?.(tool.id)} disabled={isRelaunchingTool}>
                <Wrench className="h-4 w-4" />
                {isRelaunchingTool ? "Relaunching…" : `Relaunch ${tool.label}`}
              </Button>
            ) : null}
            <Button
              className="shrink-0"
              variant="outline"
              onClick={() => {
                window.open(tool.path, "_blank", "noopener,noreferrer");
              }}
            >
              <ArrowUpRight className="h-4 w-4" />
              Open in new tab
            </Button>
          </div>
        </CardHeader>
      </Card>

      {actionResult ? (
        <Card className={actionResult.kind === "success" ? "border-emerald-400/30" : "border-rose-400/30"}>
          <CardContent className="px-6 py-4">
            <div className={actionResult.kind === "success" ? "text-sm font-medium text-emerald-200" : "text-sm font-medium text-rose-200"}>
              {actionResult.title}
            </div>
            {actionResult.detail ? <p className="mt-2 text-sm leading-6 text-zinc-300">{actionResult.detail}</p> : null}
          </CardContent>
        </Card>
      ) : null}

      {!tool.enabled ? (
        <Card className="flex-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TriangleAlert className="h-5 w-5 text-amber-300" />
              Route disabled
            </CardTitle>
            <CardDescription>
              This tool is currently disabled in the gateway runtime. Re-enable the related `*_ENABLED`
              setting if you want it to appear live in the dashboard.
            </CardDescription>
          </CardHeader>
        </Card>
      ) : (
        <Card className="flex min-h-0 flex-1 flex-col overflow-hidden">
          <div className="border-b border-zinc-800/80 px-6 py-4 text-xs font-medium uppercase tracking-[0.22em] text-zinc-500">
            Embedded view
          </div>
          <div className="min-h-0 flex-1 bg-white">
            <iframe
              key={tool.id}
              title={tool.label}
              src={tool.path}
              className="h-full w-full border-0"
              referrerPolicy="same-origin"
            />
          </div>
        </Card>
      )}
    </div>
  );
}
