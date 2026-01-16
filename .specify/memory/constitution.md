<!--
SYNC IMPACT REPORT
==================
Version change: N/A → 1.0.0 (initial ratification)
Modified principles: N/A (new constitution)
Added sections:
  - Core Principles (5 principles: Convention over Configuration, MVC Architecture,
    RESTful Design, DRY, Test-Driven Development)
  - Development Workflow
  - Governance
Removed sections: N/A
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ (Constitution Check section compatible)
  - .specify/templates/spec-template.md ✅ (no changes needed)
  - .specify/templates/tasks-template.md ✅ (no changes needed)
Follow-up TODOs: None
-->

# Training Server Constitution

## Core Principles

### I. Convention over Configuration

All development MUST follow Rails conventions unless there is a documented, compelling
reason to deviate. This includes:

- File and directory naming conventions (snake_case for files, CamelCase for classes)
- Database table naming (plural, snake_case)
- Model/Controller/View organization
- Route definitions following RESTful resource patterns
- Asset pipeline and JavaScript organization (Stimulus controllers, Turbo)

**Rationale**: Conventions reduce decision fatigue, improve onboarding, and enable
the Rails ecosystem tools to work seamlessly.

### II. MVC Architecture

All code MUST respect the Model-View-Controller separation:

- **Models**: Business logic, validations, associations, scopes, and callbacks.
  Models MUST NOT contain presentation logic or direct HTTP concerns.
- **Views**: Presentation only. Views MUST NOT contain business logic beyond
  simple conditionals for display purposes. Use helpers and partials for reuse.
- **Controllers**: Request handling, parameter validation, and response
  orchestration. Controllers MUST be thin—delegate business logic to models
  or service objects.

Service objects (in `app/services/`) are permitted for complex operations that
span multiple models or external integrations.

**Rationale**: Clear separation enables testing in isolation and maintains
codebase navigability.

### III. RESTful Design

All routes and controllers MUST follow RESTful conventions:

- Use standard resource actions: `index`, `show`, `new`, `create`, `edit`,
  `update`, `destroy`
- Non-standard actions MUST be justified and documented
- API endpoints MUST use proper HTTP methods and status codes
- Nested resources SHOULD be limited to one level of nesting

**Rationale**: RESTful design provides predictable, self-documenting APIs and
leverages Rails routing helpers effectively.

### IV. DRY (Don't Repeat Yourself)

Code duplication MUST be eliminated through appropriate abstractions:

- Common logic MUST be extracted to concerns, helpers, or service objects
- Shared view code MUST use partials or view components
- Database queries SHOULD use scopes for reusability
- Configuration SHOULD be centralized (environment variables, Rails credentials)

However, premature abstraction MUST be avoided. The rule of three applies:
duplicate code twice before extracting.

**Rationale**: DRY reduces maintenance burden and ensures consistency, but
over-abstraction creates complexity.

### V. Test-Driven Development

All features MUST have corresponding tests:

- Models MUST have unit tests covering validations, associations, and methods
- Controllers SHOULD have integration tests for happy path and error cases
- Critical business logic MUST have comprehensive test coverage
- System tests are RECOMMENDED for user-facing workflows

Tests SHOULD be written before or alongside implementation. The test suite
MUST pass before any merge to main.

**Rationale**: Tests document expected behavior, prevent regressions, and
enable confident refactoring.

## Development Workflow

All development follows this workflow:

1. **Branch**: Create feature branch from `main` with descriptive name
2. **Implement**: Follow the principles above; commit atomically
3. **Test**: Ensure all tests pass locally (`bin/rails test`)
4. **Lint**: Run code quality checks (`bin/rubocop`, `bin/brakeman`)
5. **Review**: Submit pull request with clear description
6. **Merge**: Squash and merge after approval

Database migrations MUST be reversible when possible. Breaking changes to APIs
MUST be documented and versioned appropriately.

## Governance

This constitution supersedes all other development practices for Training Server.

**Amendment Process**:

1. Propose changes via pull request to this file
2. Document rationale for the change
3. Obtain team review and approval
4. Update version number according to semantic versioning:
   - MAJOR: Incompatible governance changes or principle removals
   - MINOR: New principles or significant expansions
   - PATCH: Clarifications and wording improvements
5. Record amendment date

**Compliance**:

- All pull requests MUST verify adherence to these principles
- Violations MUST be documented in the Complexity Tracking section of plan.md
  with justification for why the simpler approach is insufficient
- Regular reviews SHOULD assess constitution relevance and update as needed

For runtime development guidance, refer to the project README.md and docs/ directory.

**Version**: 1.0.0 | **Ratified**: 2026-01-16 | **Last Amended**: 2026-01-16
