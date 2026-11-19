#!/bin/sh
# In the guest's GUI session: every act 40 times, with the allocator setting and without.
A=/Users/admin/s/Clawd.app/Contents/Resources/animations
cd /Users/admin/s && rm -f soak-*.txt
MallocSpaceEfficient=1 ./soak $A dict 0 40 > soak-efficient.txt 2>&1
./soak $A dict 0 40 > soak-default.txt 2>&1
echo done > soak-done.txt
