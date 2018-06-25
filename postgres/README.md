# PostgreSQL

Docker service name: `database`

Running applications:
- `PostgreSQL`

Folder contents:
- `database_stencil.env`: The fields in this file are to be populated to create the actual environment file, named `database.env`.

## Description

The primary database used by Omniport is `PostgreSQL`. Since the image is directly used without building on top of it, no Dockerfile is required.

`PostgreSQL` serves as the primary, relational, SQL-based database that is used by the Django ORM for the major part of Omniport. However other databases are available such as `Redis` for use in certain apps under certain circumstances.