# Tanyo Database Projects

This repository contains the SQL database projects for the Tanyo application:

- `TanyoLogsDB` contains application logging tables and procedures.
- `TanyoAppDB` contains the application database and references the `TanyoLogsDB` DACPAC.

## Build

Build the projects in dependency order from the repository root:

```powershell
dotnet build .\TanyoLogsDB\TanyoLogsDB.sqlproj
dotnet build .\TanyoAppDB\TanyoAppDB.sqlproj
```

The generated DACPAC files are written to each project's `bin\Debug` directory and are excluded from Git.

## SQL file encoding

Save all `.sql` files as **UTF-8** (no BOM). Do not use SSMS **Unicode** / **Unicode (Big-Endian)** — those encodings are UTF-16 and GitHub shows them as binary with no readable diff.

In SSMS use **File → Save with Encoding… → UTF-8**.

## Self-hosted repository sync

The `magnusminds/TanyoDatabseSelfHosted` repository pulls this repository every five minutes through its own GitHub Actions workflow. The workflow keeps non-table SQL unchanged, including `WITH ENCRYPTION`, and removes dynamic data masking clauses from table definitions. It can also be started manually from the target repository's Actions page.

## Dev database deployment

The `Deploy dev database` GitHub Actions workflow publishes both DACPACs to the dev server only when started manually. Configure the `DEV_DB_PASSWORD` secret in the repository's `dev` environment before running it. The database server and username are defined in the workflow; the password is never stored in the repository.

## Security

Instance-level login scripts and passwords are intentionally not stored in this repository. Create logins through the deployment environment or a secure secret-management process, then deploy the database users and roles separately.
