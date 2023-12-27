IMAGE := riscv/devenv

riscv-tests:
	docker run --rm -it -v $(shell pwd):/src -w /src $(IMAGE) /bin/bash -c "make -f Makefile.in bin"

clean:
	rm -rf out target

.PHONY: riscv-tests clean
