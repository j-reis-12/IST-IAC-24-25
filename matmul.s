.data

# m0: ReLU-activated h vector (1x128)
# file goes here

# m1: First 10 rows of m1 matrix (10x128)
# file goes here

# Output array (1x10)
# file goes here

.text
main:
  # Load pointers to matrices
  la a0, m0                     # a0 = address of matrix A
  la a1, m1                     # a1 = address of matrix B
  la a6, d                      # a6 = address of output matrix C

  # Load matrix dimensions
  li a2, 1                      # a2 = rows of A = 1
  li a3, 128                    # a3 = cols of A = 128
  li a4, 128                    # a4 = rows of B = 128
  li a5, 10                     # a5 = cols of B = 10

  # Run matmul
  jal ra, matmul

  # The contents of matrix d now have the result of matmul(m0,m1)

exit:
  li a7, 10              # Exit syscall code
  ecall                  # Terminate the program

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

# =======================================================
# FUNCTION: Matrix Multiplication of 2 integer matrices
#   d = matmul(m0, m1)
#
# Arguments:
#   a0 (int*)  - pointer to the start of m0     (Matrix A)
#   a1 (int*)  - pointer to the start of m1     (Matrix B)
#   a2 (int)   - number of rows in m0 (A)             [rows_A]
#   a3 (int)   - number of columns in m0 (A)          [cols_A]
#   a4 (int)   - number of rows in m1 (B)             [rows_B]
#   a5 (int)   - number of columns in m1 (B)          [cols_B]
#   a6 (int*)  - pointer to the start of d            (Matrix C = A x B)
#
# Returns:
#   None (void); result is stored in memory pointed to by a6 (d)
#
# Exceptions:
#  - If the height or width of any of the matrices is less than 1, 
#    this function terminates the program with error core 38
#  - If the number of columns in matrix A is not equal to the number 
#    of rows in matrix B, it terminates with error code 38
# =======================================================
matmul:
    # If aX < 1, set tX = 1, else 0
    slti t1, a2, 1
    slti t2, a3, 1
    slti t3, a4, 1
    slti t4, a5, 1
    or t0, t1, t2
    or t0, t0, t3
    or t0, t0, t4
    beqz t0, matmul_continue # If t0 = 1, exit with error code 38
    li a0, 38
    j exit_with_error

    matmul_continue:
        # If columns in A != rows in B, exit with error code 38
        beq a3, a4, matmul_start
        li a0, 38
        j exit_with_error
    
    matmul_start:
        # Save variables to stack
        addi sp, sp, -20
        sw s0, 0(sp)
        sw s1, 4(sp)
        sw s2, 8(sp)
        sw s3, 12(sp)
        sw s4, 16(sp)

        li s0, 0 # Rows counter [i]

        # Save matrix pointers to avoid dotproduct overwrite
        mv s2, a0
        mv s3, a1
        mv s4, a6
        j matmul_loop_ext

    matmul_loop_ext: # Iterate rows of matrix A
        beq s0, a2, matmul_loop_ext_end # End loop if counter = rows of A
        li s1, 0 # Columns counter [j]

        matmul_loop_int: # Iterate columns of matrix B
            beq s1, a5, matmul_loop_int_end  # End loop if counter = columns of B
        
            # Store stack
            addi sp, sp, -20
            sw a2, 0(sp)
            sw a3, 4(sp)
            sw a4, 8(sp)
            sw a5, 12(sp)
            sw ra, 16(sp)

            # Set dotproduct arguments

            # A row = A ptr + i * cols_A * 4
            mul t0, s0, a3
            slli t0, t0, 2
            add a0, s2, t0
            # B column = B ptr + j * 4
            slli t1, s1, 2
            add a1, s3, t1

            mv a2, a3 # Number of elements = columns of A
            mv a3, a5 # Number of columns in B

            jal ra, dotproduct # Call dotproduct for row A and column B

            # Load stack
            lw a2, 0(sp)
            lw a3, 4(sp)
            lw a4, 8(sp)
            lw a5, 12(sp)
            lw ra, 16(sp)
            addi sp, sp, 20

            # Store result in C[i][j] = C ptr + (i * cols_B + j) * 4
            mul t2, s0, a5
            add t2, t2, s1
            slli t2, t2, 2
            add t2, s4, t2
            sw a0, 0(t2)

            addi s1, s1, 1 # Next column
            j matmul_loop_int
            
        matmul_loop_int_end:
            addi s0, s0, 1 # Next row
            j matmul_loop_ext

    matmul_loop_ext_end:
        # Reload stack
        lw s0, 0(sp)
        lw s1, 4(sp)
        lw s2, 8(sp)
        lw s3, 12(sp)
        lw s4, 16(sp)
        addi sp, sp, 20

        jr ra                    # Return to the caller

# Exits the program with an error 
# Arguments: 
# a0 (int) is the error code 
# You need to load a0 the error to a0 before to jump here
exit_with_error:
  li a7, 93            # Exit system call
  ecall                # Terminate program
