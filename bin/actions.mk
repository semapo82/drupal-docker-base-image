.PHONY: files-link check-live

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Required parameter is missing: $1$(if $2, ($2))))

default: check-live

files-link:
	$(call check_defined, public_dir)
	files_link $(public_dir)

check-live:
	@echo "OK"
