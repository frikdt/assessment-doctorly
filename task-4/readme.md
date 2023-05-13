# Doctorly Demo
## GitLab CI/CD pipeline for building, testing, and publishing `api-fdt`

The pipeline consists of 3 stages:
- Build
- Test
- Publish

Once changes had been pushed to GitLab, the pipeline will automatically start if the changes had been made in specific branches (master or a release branch)

The `Publish` stage does not run on the master branch. In order to publish the latest Docker image, the changes need to take place on a release branch e.g. rel-1.20.0
