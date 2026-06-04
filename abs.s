.data
# Allocate space for one integer
# You can change this to test other values
input_val: .word -5 

.text

main:
  # Load address of input_val into a0
  la a0, input_val
  
  # Call abs function
  jal ra, abs
	
  #Result: the absolute of the integer is now in a0

exit:
  li a7, 10              # Exit syscall code
  ecall                  # Terminate the program

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
  bge t0, zero, done   # If value >= 0, skip negation
  sub t0, x0, t0       # t0 = -t0
  sw t0, 0(a0)         # Store back to memory

done:
  jr ra
