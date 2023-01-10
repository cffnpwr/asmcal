AS = arm-linux-gnueabihf-as
LD = arm-linux-gnueabihf-ld

TARGET = calendar
BUILDDIR = build
SRCDIR = src
SRCS = $(wildcard $(SRCDIR)/*.s)
OBJS = $(addprefix $(BUILDDIR)/,$(patsubst %.s,%.o,$(notdir $(SRCS))))
HASH = md5hash

vpath %.s src


$(TARGET): $(OBJS)
	$(LD) $^ -o $@

$(BUILDDIR)/%.o: %.s $(BUILDDIR)
	$(AS) $< -o $@

$(BUILDDIR):
	mkdir -p $@

compress: $(SRCS)
	make clean
	tar zcvf $(TARGET).tar.gz $(SRCDIR)

decompress: $(TARGET).tar.gz
	tar xzvf $(TARGET).tar.gz

hash: $(SRCS)
	md5sum $(SRCS) > $(HASH)

check: $(SRCS) $(HASH)
	md5sum -c $(HASH)

clean:
	rm -rf $(BUILDDIR) $(TARGET) $(HASH)