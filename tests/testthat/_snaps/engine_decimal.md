# snapshot: Extent of Exposure / Total Duration (days) Placebo

    Code
      cat(out, sep = "\n")
    Output
       86   
      147.8 
       62.13
      182.0 
        0.0 
      210.0 

# snapshot: Duration Categories / Xanomeline High Dose

    Code
      cat(out, sep = "\n")
    Output
      72        
      72 (100.0)
      67 ( 93.1)
      49 ( 68.1)
      38 ( 52.8)
      26 ( 36.1)

# snapshot: saf_demo Age (years) Placebo column

    Code
      cat(out, sep = "\n")
    Output
      86         
      75.2 (8.59)
      76.0       
      69.2, 81.8 
      61         
      88         

# snapshot: full saf_demo Placebo column end-to-end

    Code
      cat(out, sep = "\n")
    Output
      86          
      75.2 ( 8.59)
      76.0        
      69.2, 81.8  
      52  , 89    
      14   (16.3 )
      72   (83.7 )
      53   (61.6 )
      33   (38.4 )
      78   (90.7 )
       8   ( 9.3 )
       0   ( 0.0 )
       0   ( 0.0 )
       3   ( 3.5 )
      83   (96.5 )
       0   ( 0.0 )

# snapshot: per-section saf_demo Placebo column (Demographics image)

    Code
      cat(out, sep = "\n")
    Output
      86         
      75.2 (8.59)
      76.0       
      69.2, 81.8 
      52  , 89   
      14 (16.3)  
      72 (83.7)  
      53 (61.6)  
      33 (38.4)  
      78 (90.7)  
       8 ( 9.3)  
       0 ( 0.0)  
       0 ( 0.0)  
       3 ( 3.5)  
      83 (96.5)  
       0 ( 0.0)  

# snapshot: 18 format families vs galley reference

    Code
      cat(out_lines, sep = "\n")
    Output
      === 01 missing ===
        input:  
        mine:   |    |
        galley: ||  [GAP]
        input:  -
        mine:   |-   |
        galley: ||  [GAP]
        input:  NR
        mine:   |NR  |
        galley: ||  [GAP]
        input:  BLQ
        mine:   |BLQ |
        galley: ||  [GAP]
        input:  INF
        mine:   |INF |
        galley: ||  [GAP]
        input:  -INF
        mine:   |-INF|
        galley: ||  [GAP]
      
      === 02 n_only ===
        input:  0
        mine:   |  0|
        galley: |  0|  [match]
        input:  42
        mine:   | 42|
        galley: | 42|  [match]
        input:  135
        mine:   |135|
        galley: |135|  [match]
      
      === 03 scalar_float ===
        input:  12.3
        mine:   | 12.3 |
        galley: | 12.3 |  [match]
        input:  135.20
        mine:   |135.20|
        galley: |135.20|  [match]
        input:  -2.5
        mine:   | -2.5 |
        galley: | -2.5 |  [match]
        input:  0.07
        mine:   |  0.07|
        galley: |  0.07|  [match]
      
      === 04 pvalue ===
        input:  <0.001
        mine:   |<0.001|
        galley: |<0.001|  [match]
        input:  =0.500
        mine:   |=0.500|
        galley: |=0.500|  [match]
        input:  >0.999
        mine:   |>0.999|
        galley: |>0.999|  [match]
      
      === 05 n_pct ===
        input:  0
        mine:   |  0         |
        galley: |  0         |  [match]
        input:  1 (2.2)
        mine:   |  1 (2.2)   |
        galley: |  1 (  2.2 )|  [GAP]
        input:  42 (50.0%)
        mine:   | 42 ( 50.0%)|
        galley: | 42 ( 50.0%)|  [match]
        input:  100 (100.0%)
        mine:   |100 (100.0%)|
        galley: |100 (100.0%)|  [match]
      
      === 06 n_over_N_pct ===
        input:  3/45 (6.7)
        mine:   |  3/ 45 (  6.7)|
        galley: |  3/45  (  6.7 )|  [GAP]
        input:  42/84 (50.0%)
        mine:   | 42/84 (50.0%) |
        galley: | 42/84  ( 50.0%)|  [GAP]
        input:  120/120 (100.0)
        mine:   |120/120 (100.0)|
        galley: |120/120 (100.0 )|  [GAP]
      
      === 07 n_over_N ===
        input:  0/120
        mine:   |  0/120|
        galley: |  0/120|  [match]
        input:  1/120
        mine:   |  1/120|
        galley: |  1/120|  [match]
        input:  108/120
        mine:   |108/120|
        galley: |108/120|  [match]
      
      === 08 n_over_float ===
        input:  0/234.6
        mine:   |  0/234.6|
        galley: |  0/234.6|  [match]
        input:  12/234.6
        mine:   | 12/234.6|
        galley: | 12/234.6|  [match]
        input:  108/234.6
        mine:   |108/234.6|
        galley: |108/234.6|  [match]
      
      === 09 est_spread ===
        input:  75.0 (6.75)
        mine:   | 75.0 ( 6.75)|
        galley: | 75.0 ( 6.75)|  [match]
        input:  136.8 (17.61)
        mine:   |136.8 (17.61)|
        galley: |136.8 (17.61)|  [match]
        input:  -0.0 (1.47)
        mine:   | -0.0 ( 1.47)|
        galley: | -0.0 ( 1.47)|  [match]
      
      === 10 est_spread_pct ===
        input:  0.10 (8.7%)
        mine:   |   0.10 ( 8.7%)|
        galley: |   0.10 ( 8.7%)|  [match]
        input:  52.43 (23.4%)
        mine:   |  52.43 (23.4%)|
        galley: |  52.43 (23.4%)|  [match]
        input:  1240.40 (23.4%)
        mine:   |1240.40 (23.4%)|
        galley: |1240.40 (23.4%)|  [match]
      
      === 11 est_ci ===
        input:  168.0 (152.4, 183.6)
        mine:   |168.0   (152.4, 183.6)|
        galley: |168.0   (152.4  , 183.6)|  [GAP]
        input:  14.3 (11.2, NR)
        mine:   | 14.3   (11.2, NR)    |
        galley: | 14.3   ( 11.2  ,  NR  )|  [GAP]
        input:  0.087 (0.034, NR)
        mine:   |  0.087 (0.034, NR)   |
        galley: |  0.087 (  0.034,  NR  )|  [GAP]
        input:  NR (NR, NR)
        mine:   |NR (NR, NR)           |
        galley: | NR     ( NR    ,  NR  )|  [GAP]
      
      === 12 est_ci_bracket ===
        input:  0.0 [0.0, 0.0]
        mine:   |  0.0 [ 0.0,   0.0]|
        galley: |  0.0 [ 0.0,   0.0]|  [match]
        input:  53.0 [45.0, 60.0]
        mine:   | 53.0 [45.0,  60.0]|
        galley: | 53.0 [45.0,  60.0]|  [match]
        input:  102.0 [88.4, 116.2]
        mine:   |102.0 [88.4, 116.2]|
        galley: |102.0 [88.4, 116.2]|  [match]
      
      === 13 range_pair ===
        input:  2.0, 45.0
        mine:   | 2.0, 45.0|
        galley: | 2.0, 45.0|  [match]
        input:  65.0, 88.0
        mine:   |65.0, 88.0|
        galley: |65.0, 88.0|  [match]
        input:  -5.3, 12.1
        mine:   |-5.3, 12.1|
        galley: |-5.3, 12.1|  [match]
      
      === 14 int_range ===
        input:  1 - 180
        mine:   | 1 - 180|
        galley: | 1 - 180|  [match]
        input:  10 - 365
        mine:   |10 - 365|
        galley: |10 - 365|  [match]
      
      === 15 est_ci_pval ===
        input:  -0.08 (-0.21, 0.05) 0.194
        mine:   |-0.08 (-0.21,  0.05)  0.194|
        galley: |-0.08 (-0.21,  0.05)     0.194|  [GAP]
        input:  12.40 (9.80, 15.00) <0.001
        mine:   |12.40 ( 9.80, 15.00) <0.001|
        galley: |12.40 ( 9.80, 15.00)    <0.001|  [GAP]
      
      === 16 n_pct_rate ===
        input:  0 (0.0) 0.00
        mine:   | 0 ( 0.0)  0.00|
        galley: | 0                |  [GAP]
        input:  3 (2.5) 1.28
        mine:   | 3 ( 2.5)  1.28|
        galley: | 3 ( 2.5)     1.28|  [GAP]
        input:  42 (35.0) 17.94
        mine:   |42 (35.0) 17.94|
        galley: |42 (35.0)    17.94|  [GAP]
      
      === 17 n_over_N_pct_ci ===
        input:  0/120 (0.0) [0.0, 3.0]
        mine:   |  0/120 (  0.0) [ 0.0,   3.0]|
        galley: |  0/120 (  0.0) [ 0.0,   3.0]|  [match]
        input:  12/120 (10.0) [5.6, 16.9]
        mine:   | 12/120 ( 10.0) [ 5.6,  16.9]|
        galley: | 12/120 ( 10.0) [ 5.6,  16.9]|  [match]
        input:  120/120 (100.0) [97.0, 100.0]
        mine:   |120/120 (100.0) [97.0, 100.0]|
        galley: |120/120 (100.0) [97.0, 100.0]|  [match]
      
      === 18 est_spread_pct_ci ===
        input:  8.1 (24.2%) (7.3, 8.9)
        mine:   |   8.1 (24.2%) (   7.3,    8.9)|
        galley: |   8.1 (24.2%)    (   7.3,    8.9)|  [GAP]
        input:  1240.4 (23.4%) (1124.2, 1368.8)
        mine:   |1240.4 (23.4%) (1124.2, 1368.8)|
        galley: |1240.4 (23.4%)    (1124.2, 1368.8)|  [GAP]
      
      === summary: 36 / 57 match galley (63.2%) ===

# snapshot: per-section + zero-suppress + edge-trim on saf_demo Total

    Code
      cat(out, sep = "\n")
    Output
      254         
       75.1 (8.25)
       77.0       
       70.0, 81.0 
       51  , 89   
       33 (13.0)  
      221 (87.0)  
      143 (56.3)  
      111 (43.7)  
      230 (90.6)  
       23 ( 9.1)  
        0         
        1 ( 0.4)  
       12 ( 4.7)  
      242 (95.3)  
        0         

