
# must do this 
# https://github.com/ros2/ros2/issues/1406
unset GTK_PATH

KERNEL=./kernel/kernel8-rpi3qemu.img

# gdb -nx --args \
# /home/student/qemu-9.1.1/build/qemu-system-aarch64 \
# -M raspi3b \
#     -kernel ${KERNEL} -serial null -serial mon:stdio \
#     -d int -D qemu.log 


gdb -nx \
--args \
/home/student/qemu-9.1.1/build/qemu-system-aarch64 \
-M raspi3b \
    -kernel ${KERNEL} -serial null -serial mon:stdio \
    -d int -D qemu.log 
