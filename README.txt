Mother

mixed C & Assembly BARE METAL Runtime System for the BeagleboneBlack

General Purpose I/O control, interrupt driven
UART external communication, interrupt driven
MultiMediaCard/SDcard disk storage
I2C bus communication
Pulse Width Modulation control
Real Time Clock, interrupt driven

Use this main program and Assembly drivers as a skeleton for your application 
and strip out/add on whatever you need, freely, without restriction.  

Makefile & loadscript provided for GCC in Win32 (gasp! it is all i have).  
I use the XDS100V2 jtag to load programs.  It is more work up front, but 
easier if you decide to get serious.  The file "app" (provided) will load/run 
from mmc with MLO, a quick test for you doubting Thomases.  

It is all there in very concise format, so it should be easy for noobs 
to understand/test/hack/mod for your next BBB bare metal project requiring
a stand-alone control system.  And it is interrupt-ready! (somewhat)

You can provide feedback at www.baremetal.tech  

List for the adventurous: