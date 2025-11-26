# scripts/plot_generic.gp
# Usage: gnuplot -c scripts/plot_generic.gp input.xvg output.png "Title" "X" "Y" col_idx window_size

# --- ARGUMENTS ---
input_file = ARG1
output_file = ARG2
plot_title = ARG3
x_label = ARG4
y_label = ARG5
col_idx = ARG6 + 0       # Force integer
window_size = ARG7 + 0   # Force integer

# --- SETUP ---
set terminal pngcairo size 800,600 enhanced font 'Arial,12'
set output output_file
set title plot_title
set xlabel x_label
set ylabel y_label
set grid
set datafile commentschars "#@"

# --- PLOTTING ---
if (window_size > 1) {
    # We use awk to calculate the running average on the fly.
    # It maintains a circular buffer of size 'n' to calculate the average.
    # We escape the $ sign for column selection using backslash.
    
    awk_cmd = sprintf("< awk -v n=%d -v c=%d ' \
        BEGIN { i=0; sum=0 } \
        /^[@#]/ { next } \
        { \
            val=$c; \
            i++; \
            idx = i %% n; \
            if (i > n) sum -= buffer[idx]; \
            buffer[idx] = val; \
            sum += val; \
            count = (i < n) ? i : n; \
            print $1, sum/count; \
        }' %s", window_size, col_idx, input_file)

    # Plot Raw Data (light blue) and Running Average (dark blue)
    plot input_file using 1:col_idx with lines title "Raw Data" lw 1 lc rgb "#99CCFF", \
         awk_cmd using 1:2 with lines title sprintf("Running Avg (n=%d)", window_size) lw 3 lc rgb "blue"

} else {
    # Standard Plot (No smoothing)
    plot input_file using 1:col_idx with lines title y_label lw 2 lc rgb "blue"
}
