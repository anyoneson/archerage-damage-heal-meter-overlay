import { invoke } from "@tauri-apps/api/core";
import "./style.css";

type LogType = "damage" | "heal";

type AppConfig = {
  overlayPosition: [number, number];
  overlayWidth: number;
  overlayHeight: number;
  overlayFontSize: number;
  overlayLogsFontSize: number;
  overlayOpacity: string;
  overlayLogColor: string;
  logFilePath: string;
  logMinutesAgo: number;
  targetName: string;
  logType: LogType;
};

type MeterRow = {
  rank: number;
  name: string;
  total: number;
  totalFormatted: string;
};

type MeterSnapshot = {
  rows: MeterRow[];
  logType: LogType;
  sourcePath: string;
  trackedEvents: number;
  updatedAt: string;
};

const appRoot = document.querySelector<HTMLDivElement>("#app")!;

let config: AppConfig | null = null;
let snapshot: MeterSnapshot | null = null;
let errorMessage = "";
let settingsOpen = false;
let collapsed = false;

const defaultConfig: AppConfig = {
  overlayPosition: [30, 30],
  overlayWidth: 330,
  overlayHeight: 270,
  overlayFontSize: 14,
  overlayLogsFontSize: 12,
  overlayOpacity: "7",
  overlayLogColor: "#ff55ff",
  logFilePath: "",
  logMinutesAgo: 10,
  targetName: "",
  logType: "damage"
};

function currentConfig(): AppConfig {
  return config ?? defaultConfig;
}

function opacityValue(value: string): number {
  const parsed = Number.parseInt(value.replace("%", ""), 10);
  if (Number.isNaN(parsed)) {
    return 0.12;
  }
  return Math.min(Math.max(parsed, 1), 100) / 100;
}

function applyTheme(nextConfig: AppConfig): void {
  document.documentElement.style.setProperty("--accent", nextConfig.overlayLogColor);
  document.documentElement.style.setProperty("--panel-alpha", String(opacityValue(nextConfig.overlayOpacity)));
  document.documentElement.style.setProperty("--font-size", `${nextConfig.overlayFontSize}px`);
  document.documentElement.style.setProperty("--log-font-size", `${nextConfig.overlayLogsFontSize}px`);
}

function button(label: string, onClick: () => void): HTMLButtonElement {
  const element = document.createElement("button");
  element.type = "button";
  element.textContent = label;
  element.addEventListener("click", onClick);
  return element;
}

function field(labelText: string, input: HTMLInputElement | HTMLSelectElement): HTMLLabelElement {
  const label = document.createElement("label");
  const span = document.createElement("span");
  span.textContent = labelText;
  label.append(span, input);
  return label;
}

function input(value: string, type = "text"): HTMLInputElement {
  const element = document.createElement("input");
  element.type = type;
  element.value = value;
  return element;
}

async function loadConfig(): Promise<void> {
  config = await invoke<AppConfig>("get_config");
  applyTheme(config);
}

async function refreshSnapshot(): Promise<void> {
  if (collapsed || settingsOpen) {
    return;
  }

  try {
    snapshot = await invoke<MeterSnapshot>("get_meter_snapshot");
    errorMessage = "";
  } catch (error) {
    errorMessage = String(error);
  }

  if (collapsed || settingsOpen) {
    return;
  }

  render();
}

async function saveSettings(form: HTMLFormElement): Promise<void> {
  const data = new FormData(form);
  const nextConfig: AppConfig = {
    ...currentConfig(),
    overlayWidth: Number(data.get("overlayWidth")) || defaultConfig.overlayWidth,
    overlayHeight: Number(data.get("overlayHeight")) || defaultConfig.overlayHeight,
    overlayFontSize: Number(data.get("overlayFontSize")) || defaultConfig.overlayFontSize,
    overlayLogsFontSize: Number(data.get("overlayLogsFontSize")) || defaultConfig.overlayLogsFontSize,
    overlayOpacity: String(data.get("overlayOpacity") ?? defaultConfig.overlayOpacity),
    overlayLogColor: String(data.get("overlayLogColor") ?? defaultConfig.overlayLogColor),
    logFilePath: String(data.get("logFilePath") ?? ""),
    logMinutesAgo: Number(data.get("logMinutesAgo")) || defaultConfig.logMinutesAgo,
    targetName: String(data.get("targetName") ?? ""),
    logType: String(data.get("logType") ?? "damage") as LogType
  };

  config = await invoke<AppConfig>("save_config", { config: nextConfig });
  applyTheme(config);
  settingsOpen = false;
  await refreshSnapshot();
}

function renderToolbar(root: HTMLElement): void {
  const toolbar = document.createElement("div");
  toolbar.className = "toolbar";
  toolbar.addEventListener("mousedown", (event) => {
    if (event.target === toolbar) {
      void invoke("start_drag");
    }
  });

  const left = document.createElement("div");
  left.className = "toolbar-group";
  left.append(
    button(collapsed ? "+" : "-", () => {
      collapsed = !collapsed;
      render();
    }),
    button("Set time", async () => {
      await invoke("set_time_filter_now");
      await refreshSnapshot();
    })
  );

  const right = document.createElement("div");
  right.className = "toolbar-group";
  right.append(
    button("Settings", () => {
      settingsOpen = !settingsOpen;
      render();
    }),
    button("Exit", () => {
      void invoke("close_window");
    })
  );

  toolbar.append(left, right);
  root.append(toolbar);
}

function renderRows(root: HTMLElement): void {
  const table = document.createElement("div");
  table.className = "meter-table";

  const headerName = document.createElement("div");
  headerName.className = "meter-header";
  headerName.textContent = "Rank - Name";

  const headerTotal = document.createElement("div");
  headerTotal.className = "meter-header align-right";
  headerTotal.textContent = currentConfig().logType === "heal" ? "Heal" : "Damage";

  table.append(headerName, headerTotal);

  if (snapshot?.rows.length) {
    for (const row of snapshot.rows) {
      const name = document.createElement("div");
      name.className = "meter-cell player";
      name.textContent = `${row.rank} ${row.name}`;

      const total = document.createElement("div");
      total.className = "meter-cell total";
      total.textContent = row.totalFormatted;

      table.append(name, total);
    }
  } else {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = errorMessage || "No combat data";
    table.append(empty);
  }

  root.append(table);
}

function renderSettings(root: HTMLElement): void {
  const cfg = currentConfig();
  const form = document.createElement("form");
  form.className = "settings";
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    void saveSettings(form);
  });

  const logType = document.createElement("select");
  logType.name = "logType";
  for (const value of ["damage", "heal"] as const) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    option.selected = cfg.logType === value;
    logType.append(option);
  }

  const logFilePath = input(cfg.logFilePath);
  logFilePath.name = "logFilePath";

  const targetName = input(cfg.targetName);
  targetName.name = "targetName";

  const logMinutesAgo = input(String(cfg.logMinutesAgo), "number");
  logMinutesAgo.name = "logMinutesAgo";
  logMinutesAgo.min = "1";

  const overlayWidth = input(String(cfg.overlayWidth), "number");
  overlayWidth.name = "overlayWidth";
  overlayWidth.min = "120";

  const overlayHeight = input(String(cfg.overlayHeight), "number");
  overlayHeight.name = "overlayHeight";
  overlayHeight.min = "80";

  const overlayFontSize = input(String(cfg.overlayFontSize), "number");
  overlayFontSize.name = "overlayFontSize";
  overlayFontSize.min = "8";

  const overlayLogsFontSize = input(String(cfg.overlayLogsFontSize), "number");
  overlayLogsFontSize.name = "overlayLogsFontSize";
  overlayLogsFontSize.min = "8";

  const overlayOpacity = input(cfg.overlayOpacity, "number");
  overlayOpacity.name = "overlayOpacity";
  overlayOpacity.min = "1";
  overlayOpacity.max = "100";

  const overlayLogColor = input(cfg.overlayLogColor, "color");
  overlayLogColor.name = "overlayLogColor";

  form.append(
    field("Log file path", logFilePath),
    field("Log type", logType),
    field("Target name", targetName),
    field("Minutes ago", logMinutesAgo),
    field("Overlay width", overlayWidth),
    field("Overlay height", overlayHeight),
    field("Overlay font size", overlayFontSize),
    field("Log font size", overlayLogsFontSize),
    field("Opacity", overlayOpacity),
    field("Log color", overlayLogColor)
  );

  const actions = document.createElement("div");
  actions.className = "settings-actions";
  actions.append(
    button("Cancel", () => {
      settingsOpen = false;
      render();
    }),
    button("Save", () => {
      form.requestSubmit();
    })
  );

  form.append(actions);
  root.append(form);
}

function renderStatus(root: HTMLElement): void {
  const status = document.createElement("div");
  status.className = "status";
  status.textContent = errorMessage || `${snapshot?.trackedEvents ?? 0} events`;
  root.append(status);
}

function render(): void {
  const cfg = currentConfig();
  applyTheme(cfg);
  appRoot.replaceChildren();

  const root = document.createElement("main");
  root.className = collapsed ? "overlay collapsed" : "overlay";
  renderToolbar(root);

  if (!collapsed) {
    if (settingsOpen) {
      renderSettings(root);
    } else {
      renderRows(root);
      renderStatus(root);
    }
  }

  appRoot.append(root);
}

void loadConfig()
  .catch((error) => {
    errorMessage = String(error);
  })
  .finally(() => {
    render();
    void refreshSnapshot();
    window.setInterval(() => {
      void refreshSnapshot();
    }, 1000);
  });
