.data
# Sample input arrays
# You can change this array to test other values (remember to modify the dimensions in the main)

arr0: .word 1, 2, 3, 4
arr1: .word 10, 20, 30, 40

.text

main:	
    # Set up arguments for dotproduct(arr0, arr1, 4, 1)
    la a0, arr0         # a0 = &arr0
    la a1, arr1         # a1 = &arr1
    li a2, 4            # a2 = number of elements
    li a3, 1            # a3 - number of columns in arr1

    jal ra, dotproduct  # Call dotproduct function

    # The result of the dot product is now in a0
    
exit:
    li a7, 10     # Exit syscall code
    ecall         # Terminate the program

# =======================================================
# FUNCTION: Dot product of 2 int arrays
# Arguments:
#   a0 (int*) - Pointer to the start of arr0
#   a1 (int*) - Pointer to the start of arr1
#   a2 (int)  - Number of elements to use
#   a3 (int)  - Number of columns of arr1
# Returns:
#   a0 (int)  - The dot product of arr0 and arr1
# Exceptions:
#   - If a2 < 1, exit with error code 38
# =======================================================
dotproduct:
    li t0 0 # Counter
    li t1 0 # Multply aux
    li t2 0 # Result
    slli t5, a3, 2 # t5 = a3 * 4

    bgt a2, zero, dotproduct_loop # If array length < 1, exit with error code 36
    li a0, 36
    j exit_with_error

    dotproduct_loop:
        beq t0, a2, dotproduct_loop_end # End loop when array limit is reached

        # Multiply elements and sum to t2
        lw t3, 0(a0)
        lw t4, 0(a1)
        mul t1, t3, t4
        add t2, t2, t1

        # Increment counter and array pointers
        addi t0, t0, 1
        addi a0, a0, 4 # Next element in A
        add a1, a1, t5 # a1 = a1 + (a3 * 4), next element in column of B
        j dotproduct_loop

    dotproduct_loop_end:
        mv a0, t2 # Return result
        jr ra                    # Return to the caller

# Exits the program with an error 
# Arguments: 
# a0 (int) is the error code 
# You need to load a0 the error to a0 before to jump here
exit_with_error:
  li a7, 93            # Exit system call
  ecall                # Terminate program
