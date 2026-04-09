## Handoff: team-plan → team-exec
- **Decided**: 3 executor workers for Phases 0,2,4,5,6. Lead handles Phase 1 (AIService/core) and Phase 3 (presentation Controllers). Full Riverpod+go_router removal. ScreenUtil design size 1920x1080.
- **Rejected**: Keeping Riverpod alongside GetX (user wants full replacement), keeping go_router (user wants GetX routing).
- **Risks**: AIService deeply coupled to Riverpod Ref (Phase 1, lead handles). Presentation pages overlap between routing changes (Phase 4) and ScreenUtil changes (Phase 5) — Phase 5 blocked on Phase 4.
- **Files**: Plan at .claude/plans/zesty-pondering-lightning.md
- **Remaining**: Phase 1 (core services), Phase 3 (19 GetxControllers) — lead handles separately.
