import { useState } from "react";
import { Check, Copy, FolderKanban, HelpCircle, Keyboard, TerminalSquare } from "lucide-react";

import type { ToolDefinition, ToolHelpSection } from "./tool-frame";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "./ui/dialog";

async function copyText(value: string) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value);
    return;
  }

  const textArea = document.createElement("textarea");
  textArea.value = value;
  textArea.setAttribute("readonly", "true");
  textArea.style.position = "absolute";
  textArea.style.left = "-9999px";
  document.body.appendChild(textArea);
  textArea.select();
  document.execCommand("copy");
  document.body.removeChild(textArea);
}

function CopyRow({
  itemId,
  value,
  label,
  description,
  copiedId,
  onCopy,
}: {
  itemId: string;
  value: string;
  label: string;
  description?: string;
  copiedId: string | null;
  onCopy: (id: string, value: string) => void;
}) {
  const isCopied = copiedId === itemId;

  return (
    <div className="rounded-2xl border border-zinc-800/80 bg-zinc-900/55 px-4 py-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-1">
          <div className="text-sm font-medium text-zinc-50">{label}</div>
          {description ? <p className="text-sm leading-6 text-zinc-400">{description}</p> : null}
        </div>
        <Button variant={isCopied ? "secondary" : "outline"} size="sm" onClick={() => onCopy(itemId, value)}>
          {isCopied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
          {isCopied ? "Copied" : "Copy"}
        </Button>
      </div>
      <pre className="mt-4 overflow-x-auto rounded-xl bg-zinc-950/90 px-3 py-3 text-sm text-cyan-100 ring-1 ring-inset ring-zinc-800/80">
        <code>{value}</code>
      </pre>
    </div>
  );
}

function DirectoryRow({
  directory,
  itemId,
  copiedId,
  onCopy,
}: {
  directory: string;
  itemId: string;
  copiedId: string | null;
  onCopy: (id: string, value: string) => void;
}) {
  const isCopied = copiedId === itemId;

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-zinc-900/50 px-3 py-3 ring-1 ring-inset ring-zinc-800/70">
      <code className="text-sm text-zinc-200">{directory}</code>
      <Button variant={isCopied ? "secondary" : "outline"} size="sm" onClick={() => onCopy(itemId, directory)}>
        {isCopied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
        {isCopied ? "Copied" : "Copy path"}
      </Button>
    </div>
  );
}

function SectionIcon({ section }: { section: ToolHelpSection }) {
  if (section.commands?.length) return <TerminalSquare className="h-4 w-4" />;
  if (section.directories?.length) return <FolderKanban className="h-4 w-4" />;
  return <Keyboard className="h-4 w-4" />;
}

export function ToolHelpDialog({ brandName, tool }: { brandName: string; tool: ToolDefinition }) {
  const help = tool.help;
  const [copiedId, setCopiedId] = useState<string | null>(null);

  if (!help) return null;

  const handleCopy = (id: string, value: string) => {
    void copyText(value)
      .then(() => {
        setCopiedId(id);
        window.setTimeout(() => {
          setCopiedId((currentId) => (currentId === id ? null : currentId));
        }, 1600);
      })
      .catch(() => {
        setCopiedId(null);
      });
  };

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="secondary">
          <HelpCircle className="h-4 w-4" />
          Help
        </Button>
      </DialogTrigger>
      <DialogContent className="border-zinc-800/80 bg-[linear-gradient(180deg,rgba(17,24,39,0.96)_0%,rgba(9,9,11,0.98)_100%)]">
        <DialogHeader className="border-b border-zinc-800/80 pb-5 pr-20">
          <div className="flex flex-wrap items-center gap-3">
            <Badge>{brandName}</Badge>
            <Badge variant="muted">{tool.label}</Badge>
          </div>
          <DialogTitle>{help.title}</DialogTitle>
          <DialogDescription>{help.description}</DialogDescription>
        </DialogHeader>

        <div className="overflow-y-auto px-6 pb-6 pt-3">
          <div>
            {help.sections.map((section, sectionIndex) => (
              <section
                key={`${tool.id}-${section.title}`}
                className={sectionIndex === 0 ? "py-5" : "border-t border-zinc-800/80 py-5"}
              >
                <div className="flex items-start gap-4">
                  <div className="mt-0.5 rounded-full border border-cyan-400/30 bg-cyan-400/10 p-2 text-cyan-200 shadow-[0_0_0_1px_rgba(34,211,238,0.08)]">
                    <SectionIcon section={section} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <h3 className="text-base font-semibold text-zinc-50">{section.title}</h3>
                    {section.description ? <p className="mt-1 max-w-3xl text-sm leading-6 text-zinc-400">{section.description}</p> : null}

                    {section.tips?.length ? (
                      <div className="mt-4 space-y-2.5">
                        {section.tips.map((tip) => (
                          <p key={tip} className="max-w-4xl text-sm leading-6 text-zinc-300">
                            {tip}
                          </p>
                        ))}
                      </div>
                    ) : null}

                    {section.commands?.length ? (
                      <div className="mt-5 grid gap-3">
                        {section.commands.map((command, commandIndex) => (
                          <CopyRow
                            key={`${section.title}-${command.label}`}
                            itemId={`${tool.id}-command-${sectionIndex}-${commandIndex}`}
                            value={command.command}
                            label={command.label}
                            description={command.description}
                            copiedId={copiedId}
                            onCopy={handleCopy}
                          />
                        ))}
                      </div>
                    ) : null}

                    {section.directories?.length ? (
                      <div className="mt-5 grid gap-2.5">
                        {section.directories.map((directory, directoryIndex) => (
                          <DirectoryRow
                            key={`${section.title}-${directory}`}
                            directory={directory}
                            itemId={`${tool.id}-directory-${sectionIndex}-${directoryIndex}`}
                            copiedId={copiedId}
                            onCopy={handleCopy}
                          />
                        ))}
                      </div>
                    ) : null}
                  </div>
                </div>
              </section>
            ))}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
