# Environment

The Omniport project loads all settings from JSON configuration files. The `docker-compose.yml` file takes care of loading the set of these configuration files into the Django container from this directory.

# How to use

- Use the JSON schema `base-schema.json` to create `base.json`.
- Go to the `sites` folder.
- For as many sites as you are deploying (plus the development site), use the JSON schema `site-schema.json` to create `site_<site_id>.json`.
    - In this specific case the following site IDs are being followed.
        - **Site ID 0:** the development site, launched by `start-the-dj.sh`
        - **Site ID 1:** the Intranet facing site
        - **Site ID 2:** the Internet facing site