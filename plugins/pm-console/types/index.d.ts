export type InboxItem = {
  id: string
  text: string
  lane: string
  ref: string
  at: number
  isDone: boolean
  // What the cycle reported, for the detail view; the same on every item of one report.
  detail?: string
  url?: string
}
export type LaneRow = {
  id: string
  description: string
  status: string
  model: string
  startedAt: number
}
export type CiRow = {
  repo: string
  workflow: string
  runs: number
  avgSec: number
  maxSec: number
}
// repos: how many repos the stats were read from; 0 means none set yet.
export type CiStats = { at: number; rows: CiRow[]; error: string; repos: number }
export type PapRow = {
  repo: string
  version: string
  drift: string
  proposed: string[]
  revisitsDue: number
  revisitsManual: number
  experiments: { open: number; building: number; built: number; dropped: number }
  nextExperiment: string
  openPrs: number
  awaitingReview: number
  leadTimeDays: number
  error: string
}
export type PapStats = { at: number; latest: string; rows: PapRow[]; repos: number }

declare module 'claude-code' {
  interface PluginState {
    'pm-console': {
      inbox: Shaped<InboxItem[]>
      lanes: LaneRow[]
      ci: CiStats
      pap: PapStats
      tab: string
      openGroup: string
    }
  }
}
