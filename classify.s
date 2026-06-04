# ===========================================================
# Top-5 das otimizacoes:
#
# 1. Conversão de matrizes para binário numa função separada, com
# ajuste dos valores incorporado durante a conversão.
#
# 2. Funcção dotproduct com execução em linhas/colunas arbitrárias
# das matrizes (por exemplo, no meio), com argumento suporte de salto/stride.
#
# 3. Função matmul com duplo loop de chamadas à função dotproduct (respeitando
# a convenção de chamada RISC-V no processo).
#
# 4. Skip do cabeçalho da matriz input diretamente na função classify,
# antes da conversão da matriz.
#
# 5. Travessia direta do array na função argmax, guardando os valores
# necessários exclusivamente em registos temporários para menor latência.
#
# ===========================================================

.data

# ===========================================================
#Main data structures. These definitions cannot be changed.

h_m0: .word 128
w_m0: .word 784
m0: .zero 401408                #h_m0 * w_m0 * 4 bytes

h_m1: .word 10
w_m1: .word 128
m1: .zero 5120                  #h_m1 * w_m1 * 4 bytes

h_input: .word 784
w_input: .word 1
input: .zero 3136               #h_input * w_input * 4 bytes

h_h: .word 128
w_h: .word 1
h: .zero 512                    #h_h * w_h * 4 bytes

h_o: .word 10
w_o: .word 1
o: .zero 40                     #h_o * w_o * 4 bytes

# ===========================================================

# Matrix file paths (change to local/absolute path if needed)
file_input: .string "input0.bin" # Input matrix
file_m0: .string "m0.bin" # m0 weight matrix
file_m1: .string "m1.bin" # m1 weight matrix

# Temporary buffer for the (raw) 8-bit matrixes
buffer_8bit: .zero 100352 # Largest size, m0 = 128 * 784

# ===========================================================
.text

main:
    # Set up arguments for *classify* function
    la a0, m0
    la a1, m1
    la a2, input

    # Call *classify* function
    jal, ra, classify

    # Print the classified digit (in the Ripes console) and exit
    li, a7, 1
    ecall
    j exit

# ===========================================================
# FUNCTION: abs
#   Computes absolute value of the int stored at a0
# Arguments:
#   a0, a pointer to int
# Returns:
#   Nothing (modifies value in memory)
# ===========================================================
abs:
    lw t0, 0(a0)         # Load int value
    bge t0, zero, abs_done   # If value >= 0, skip negation
    sub t0, x0, t0       # t0 = -t0
    sw t0, 0(a0)         # Store back to memory

abs_done:
    jr ra                    # Return to the caller

# ============================================================
# FUNCTION: relu
#   Applies ReLU on each element of the array (in-place)
# Arguments:
#   a0 = pointer to int array
#   a1 = array length
# Exceptions:
#   - If the length of the array is less than 1,
#     this function terminates the program with error code 36
# ============================================================
relu:

    li t3, 0 # Initialize array counter
    bgt a1, x0, relu_loop_start # If array length < 1, exit with error 36
    li a0, 36 # Load a0 with error code
    j exit_with_error

    relu_loop_start:
    beq t3, a1, relu_loop_end # End loop if end of the array is reached
    lw t0, 0(a0) # Load array element

    bge t0, x0, relu_done # If element < 0, replace with 0
    li t0, 0
    sw t0, 0(a0)

    relu_done:
    addi a0, a0, 4 # Go to the next element
    addi t3, t3, 1 # i++
    j relu_loop_start

    relu_loop_end:
        jr ra                    # Return to the caller

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
#     this function terminates the program with error code 37
# =================================================================
argmax:
    li t3, 0 # Array counter
    lw t1, 0(a0) # Max element
    li t2, 0 # Max element index
    bgt a1, x0, argmax_loop_start # If array length < 1, exit with error 36
    li a0, 37 # Load a0 with error code
    j exit_with_error

argmax_loop_start:
    beq t3, a1, argmax_loop_end # End loop if end of the array is reached
    lw t0, 0(a0) # Load array element

    ble t0, t1, argmax_loop_next # If element > max, replace max element and index
    addi t1, t0, 0
    addi t2, t3, 0

argmax_loop_next:
    addi a0, a0, 4 # Go to the next element
    addi t3, t3, 1 # i++
    j argmax_loop_start

argmax_loop_end:
    addi a0, t2, 0 # Write max element index in a0
    jr ra                    # Return to the caller

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
    li a0, 38
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
#    this function terminates the program with error core 39
#  - If the number of columns in matrix A is not equal to the number 
#    of rows in matrix B, it terminates with error code 40
# =======================================================
matmul:
    # Check if height/width < 1
    # If aX < 1, set tX = 1, else 0
    slti t1, a2, 1
    slti t2, a3, 1
    slti t3, a4, 1
    slti t4, a5, 1
    or t0, t1, t2
    or t0, t0, t3
    or t0, t0, t4
    beqz t0, matmul_continue # If t0 = 1, exit with error code 39
    li a0, 39
    j exit_with_error

    matmul_continue:
        # If columns in A != rows in B, exit with error code 40
        beq a3, a4, matmul_start
        li a0, 40
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

######################################################################
# Function: read_file(char* filename, byte* buffer, int length)
# Input:
#   a0: pointer to null-terminated filename string
#   a1: destination buffer
#   a2: number of bytes to read
# Output:
#   a0: number of bytes read (return value from syscall)
# Exceptions:
#   - Error code 41 if error in the file descriptor
#   - Error code 42 If the length of the bytes to read is less than 1
######################################################################
read_file:
    # Check if length < 1 (error code 42)
    bgt a2, zero, read_file_open
    li a0, 42
    j exit_with_error

    read_file_open:
        mv t1, a0           # Save filename pointer
        mv t2, a1           # Save buffer pointer

        mv a1, zero         # No flags (read only)
        li a7, 1024         # Syscall open
        ecall
        bgez a0, read_file_read       # If fd < 0, exit with error code 41
        li a0, 41
        j exit_with_error

    read_file_read:
        mv t1, a0           # Save file descriptor
        mv a1, t2           # Reload buffer pointer
        # Note: number of bytes to read is still in the right spot (a2)
        li a7, 63           # Syscall read
        ecall
        mv a1, a0           # Save bytes read

        mv a0, t1           # Reload file descriptor
        li a7, 57           # Syscall close
        ecall
        mv a0, a1           # Return bytes read
        jr ra                    # Return to the caller

# =======================================================
# FUNCTION: Converts an array of 8-bit integers to 32-bit values
#           Can also add an integer to each converted value
#
# Arguments:
#   a0 (int*)  - pointer to the 8-bit source buffer
#   a1 (int*)  - pointer to the 32-bit destination buffer
#   a2 (int)   - number of bytes to convert
#   a3 (int)   - number to add to each byte
#
# Returns:
#   Nothing (modifies value in memory)
# =======================================================
convert_8bit_to_32bit:
    beqz a2, convert_loop_end
    
    convert_loop:
        lbu t0, 0(a0)
        add t0, t0, a3           # Add adjustment value
        sw t0, 0(a1)
        # Advance to next bit and byte
        addi a0, a0, 1
        addi a1, a1, 4
        addi a2, a2, -1
        bnez a2, convert_loop
    
    convert_loop_end:
        jr ra                    # Return to the caller

# =======================================================
# FUNCTION: Classify decimal digit from input image
#   d = classify(A, B, input)
#
# Arguments:
#   a0 (int*)  - pointer to the start of weight matrix, m0
#   a1 (int*)  - pointer to the start of weight matrix, m1
#   a2 (int*)  - pointer to the start of input matrix
#
# Returns:
#   a0 (int) - value of the classified decimal digit
#
# =======================================================
classify:
    # Save ra and caller variables to stack
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)

    # Save function arguments
    mv s0, a0
    mv s1, a1
    mv s2, a2

    # Load m0, m1 and input matrixes calling *read_file* function
    # Convert from 8-bit buffer to 32-bit calling *convert_8bit_to_32_bit* function
    # Adjust each value by subtracting 32

    # m0
    la  a0, file_m0        # Pointer to m0
    la  a1, buffer_8bit    # m0 buffer
    li  a2, 100352         # Buffer size
    jal ra, read_file

    mv a2, a0              # *read_file* output, number of bytes read
    la a0, buffer_8bit     # Source buffer
    mv a1, s0              # Destination (m0)
    li a3, -32             # Weight matrix value adjustment
    jal ra, convert_8bit_to_32bit

    # m1
    la  a0, file_m1        # Pointer to m1
    la  a1, buffer_8bit
    li  a2, 100352
    jal ra, read_file

    mv a2, a0
    la a0, buffer_8bit
    mv a1, s1              # Destination (m1)
    li a3, -32
    jal ra, convert_8bit_to_32bit

    # input
    la  a0, file_input     # Pointer to input
    la  a1, buffer_8bit
    li  a2, 100352
    jal ra, read_file

    # Skips the header (12 bytes) for the input file
    addi a2, a0, -12       # -12 bytes to read
    la a0, buffer_8bit
    addi a0, a0, 12        # Relocate pointer
    mv a1, s2              # Destination (input)
    li a3, 0               # No adjustment needed for input
    jal ra, convert_8bit_to_32bit

    # Set up arguments for *matmul* function
    mv a0, s0              # Pointer to m0
    mv a1, s2              # Pointer to input
    lw a2, h_m0            # Rows of m0
    lw a3, w_m0            # Cols of m0
    lw a4, h_input         # Rows of input
    lw a5, w_input         # Cols of input
    la a6, h               # Pointer to h
    jal ra, matmul         # Compute h matrix = matmul(m0, input)

    # Set up arguments for *relu* function
    la a0, h               # matmul input, pointer to h
    lw, a1, h_h            # h rows, number of elements
    jal ra, relu           # Execute relu(h)

    # Set up arguments for *matmul* function
    mv a0, s1              # Pointer to m1
    la a1, h               # Pointer to h
    lw a2, h_m1            # Rows of m1
    lw a3, w_m1            # Cols of m1
    lw a4, h_h             # Rows of h
    lw a5, w_h             # Cols of h
    la a6, o               # Pointer to o
    jal ra, matmul         # Compute o matrix = matmul(m1, h)

    # Set up arguments for *argmax* function
    la a0, o               # Pointer to o
    lw, a1, h_o            # Rows of o = number of elements
    jal ra, argmax         # Execute argmax(o)
    
    # Reload stack
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    addi sp, sp, 16

    jr ra                    # Return to the caller

# =======================================================
# Exit procedures
# =======================================================

# Exits the program (with code 0)
exit:
    li a7, 10     # Exit syscall code
    ecall         # Terminate the program

# Exits the program with an error 
# Arguments: 
# a0 (int) is the error code 
# You need to load a0 the error to a0 before to jump here
exit_with_error:
  li a7, 93            # Exit system call
  ecall                # Terminate program
