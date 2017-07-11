# Integration test for Tsuru on Google Compute Engine

[![CircleCI](https://circleci.com/gh/tsuru/integration_gce.svg?style=svg)](https://circleci.com/gh/tsuru/integration_gce)

This project should make it easier to run Tsuru integration test on Google Compute Engine.

Required environment variables:

- *GCE_PROJECT_ID*: ID for a project created in GCE
- *GCE_ZONE*: the [GCE zone](https://cloud.google.com/compute/docs/regions-zones/regions-zones) where you want the Tsuru instance to be created
- *GCE_SERVICE_ACCOUNT*: [Service account](https://cloud.google.com/compute/docs/access/service-accounts) data
