# Integration test for Tsuru on Google Cloud Engine

This project should make it easier to run Tsuru integration test on Google Cloud Engine.

Required environment variables:

- *GCE_PROJECT_ID*: ID for a project created in GCE
- *GCE_ZONE*: the [GCE zone](https://cloud.google.com/compute/docs/regions-zones/regions-zones) where you want the Tsuru instance to be created
- *GCE_SERVICE_ACCOUNT_FILE*: full path to a [service account](https://cloud.google.com/compute/docs/access/service-accounts) file
