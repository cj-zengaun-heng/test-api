SHELL = /bin/bash
.SHELLFLAGS = -o pipefail -c

ifdef CI
DOCKER_BUILD_PROGRESS = plain
else
DOCKER_BUILD_PROGRESS = auto
endif

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
HELPER_RUN = BUILDKIT_PROGRESS=$(DOCKER_BUILD_PROGRESS) docker compose --ansi=never run --user $(shell id -u):$(shell id -g) --rm ssot-api-helper

GIT_VERSION_TAG := $(shell git describe --long || echo "0.0.0")
OPENAPI_SPEC_FILE := docs/ssot-openapi.json
LAMBDA_PACKAGE_ZIP := lambda-package.zip
LAMBDA_BUCKET := ew1-cujo-labs-shared-lambda-repo
PKGS_ENV_DIR := .pkgs-env
TEST_ENV_DIR := .test-env
VERSION_FILE := app/version.py
SOURCE_FILES := $(call rwildcard,app,*.py)


$(TEST_ENV_DIR): tests/requirements.txt
	$(HELPER_RUN) python -m venv $(TEST_ENV_DIR) \
		&& $(HELPER_RUN) $(TEST_ENV_DIR)/bin/pip install pip --upgrade \
		&& $(HELPER_RUN) $(TEST_ENV_DIR)/bin/pip install -r app/requirements.txt \
		&& $(HELPER_RUN) $(TEST_ENV_DIR)/bin/pip install -r tests/requirements.txt
	touch $(TEST_ENV_DIR)


$(PKGS_ENV_DIR): app/requirements.txt
	$(HELPER_RUN) python -m venv $(PKGS_ENV_DIR) \
		&& $(HELPER_RUN) $(PKGS_ENV_DIR)/bin/pip install pip --upgrade \
		&& $(HELPER_RUN) $(PKGS_ENV_DIR)/bin/pip install -r app/requirements.txt
	touch $(PKGS_ENV_DIR)


$(OPENAPI_SPEC_FILE): $(SOURCE_FILES) $(TEST_ENV_DIR)
	$(HELPER_RUN) $(TEST_ENV_DIR)/bin/python tools/extract-openapi.py "handler:app" --app-dir ./app/ --out ${OPENAPI_SPEC_FILE}


$(VERSION_FILE): $(SOURCE_FILES)
	echo "VERSION = \"$(GIT_VERSION_TAG)\"" > $(VERSION_FILE)


build-openapi: $(OPENAPI_SPEC_FILE) $(VERSION_FILE)


build-docs: $(TEST_ENV_DIR) build-openapi
	$(HELPER_RUN) $(TEST_ENV_DIR)/bin/mkdocs build \
		&& $(HELPER_RUN) grep -v '<span class="small-note">⚠️</span>&nbsp;<em class="small-note warning">This example has been generated automatically from the schema and it is not accurate. Refer to the schema for more information.</em></p>' site/openapi/index.html > site/openapi/index.html.new && mv site/openapi/index.html.new site/openapi/index.html


unit-test: $(TEST_ENV_DIR)
	$(HELPER_RUN) $(TEST_ENV_DIR)/bin/pytest -svv tests/unit/* --junitxml=ssot-api-lambda.xml


pylint: $(TEST_ENV_DIR)
	$(HELPER_RUN) $(TEST_ENV_DIR)/bin/pylint --rcfile pylintrc app/*.py | tee pylint.log


build-package: $(PKGS_ENV_DIR)
	$(HELPER_RUN) rm -f "${LAMBDA_PACKAGE_ZIP}" \
		&& $(HELPER_RUN) 7z a "${LAMBDA_PACKAGE_ZIP}" app/ -r -x!*requirements.txt -x!*.un~ -x!*.swp \
		&& $(HELPER_RUN) 7z a "${LAMBDA_PACKAGE_ZIP}" ./$(PKGS_ENV_DIR)/lib/*/site-packages/* -r -x!*__pycache__* -x!pip -x!pip-* -x!setuptools -x!*.dist-info -x!pkg_resources -x!easy_install.py -x!_distutils_hack -x!distutils-precedence.pth


push-s3: package
	$(HELPER_RUN) aws --version \
		&& $(HELPER_RUN) aws s3 cp "${LAMBDA_PACKAGE_ZIP}" "s3://${LAMBDA_BUCKET}/ssot-api-latest.zip" \
		&& $(HELPER_RUN) aws s3 cp "${LAMBDA_PACKAGE_ZIP}" "s3://${LAMBDA_BUCKET}/ssot-api-${GIT_VERSION_TAG}.zip"


clean:
	-rm pylint.log
	-rm -rf .pytest_cache
	-rm -rf $(TEST_ENV_DIR)
	-rm -rf $(PKGS_ENV_DIR)
	-rm -rf app.__init___1.stats
	-rm -rf ssot-api-lambda.xml
	-rm -rf $(OPENAPI_SPEC_FILE)
	-rm -rf $(LAMBDA_PACKAGE_ZIP)
	-rm -rf site/
	-docker compose --ansi=never down --rmi all
