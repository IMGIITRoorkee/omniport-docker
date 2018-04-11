# Environment

The Omniport project loads all the settings and configuration from the environment variables. The `docker-compose.yml` file takes care of populating them from a set of environent files with the extension .env from this directory.

These environment variables are defined into levels: 
- one set of settings that are common to all sites, like the database configuration and the maintainers
- one set of settings that are specific to every site, like the site ID and the name of the site

# How to use

- Copy the file `base-stencil.env` into `base.env`. Then fill up the settings there.
- Copy the file `site-stencil.env` into as many sites as you want to run, the out-of-the-box support is for two sites so create the files `internet.env` and `intranet.env`. Then fill up the settings there.