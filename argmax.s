.data
# You can change this array to test other values
array: .word 5, 9, 3, 9, 2   # Initial array values

.text

main:
    la a0, array           # Load address of the array
    li a1, 5               # Number of elements in the array

    jal ra, argmax         # Call the argmax function

    # Result: the index of the largest element is now in a0

exit:
    li a7, 10              # Exit syscall code
    ecall                  # Terminate the program

# =================================================================
# FUNCTION: Given an int array, return the index of the largest
#   element. If there are multiple, return the one
#   with the smallest index.
# Arguments:
#   a0 (int*) is the pointer to the start of the array
#   a1 (int)  is the number of elements in the array
# Returns:
#   a0 (int)  is the first index of the largest element
# Exceptions:
#   - If the length of the array is less than 1,
#     this function terminates the program with error code 36
# =================================================================
argmax:
    li t3, 0 # Array counter
    lw t1, 0(a0) # Max element
    li t2, 0 # Max element index
    bgt a1, x0, loop_start # If array length < 1, exit with error 36
    li a0, 36 # Load a0 with error code
    j exit_with_error

loop_start:
    beq t3, a1, loop_end # End loop if end of the array is reached
    lw t0, 0(a0) # Load array element

    ble t0, t1, loop_next # If element > max, replace max element and index
    addi t1, t0, 0
    addi t2, t3, 0

loop_next:
    addi a0, a0, 4 # Go to the next element
    addi t3, t3, 1 # i++
    j loop_start

loop_end:
    addi a0, t2, 0 # Write max element index in a0
    jr ra                        # Return to the caller

# Exits the program with an error 
# Arguments: 
# a0 (int) is the error code 
# You need to load a0 the error to a0 before to jump here
exit_with_error:
    li a7, 93                    # Exit system call
    ecall                        # Terminate program
