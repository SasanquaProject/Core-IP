IMAGE := riscv/devenv

setup: image
	make -C bootrom
	make -C tb/task/riscv_tests/resources

image:
	docker build -t $(IMAGE) .

.PHONY: setup image
