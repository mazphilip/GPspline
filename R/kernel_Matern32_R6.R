## R6 object #####
KernelClass_Matern32_R6 <- R6::R6Class("Matern32",
                                   cloneable = FALSE,
                                   class = FALSE,
                                   portable = FALSE,
                                   public = list(
                                     parameters = NULL,
                                     invKmatn = NULL,
                                     Kmat = NULL,
                                     Karray = NULL,
                                     B = NULL,
                                     p = NULL,
                                     stdy = 1,
                                     initialize = function(p_arg, B_arg, ext_init_parameters, std_y_arg=1, verbose=FALSE) {
                                       if (verbose) cat("Using Matern 3/2 kernel\n")
                                       B <<- B_arg
                                       p <<- p_arg
                                       parameters <<- ext_init_parameters
                                       stdy <<- std_y_arg# hand over moment for correct RMSE
                                     },
                                     kernel_mat = function(X1, X2, Z1, Z2) {
                                       # intended use for prediction
                                       Klist <- kernmat_Matern32_cpp(X1, X2, Z1, Z2, parameters) #lambda and L
                                     },
                                     kernel_mat_sym = function(X, Z) {
                                       # intended use for the gradient step
                                       Klist <- kernmat_Matern32_symmetric_cpp(X, Z, parameters)
                                       Kmat <<- Klist$full
                                       Karray <<- Klist$elements
                                       Klist
                                     },
                                     getinv_kernel = function(X, Z, noeigen=FALSE) {
                                       # get matrices and return inverse for prediction
                                       kernel_mat_sym(X, Z)
                                       invKmatList <- invkernel_cpp(Kmat, c(parameters[1])) #no error handling
                                       invKmatn <<- invKmatList$inv
                                       invKmatList
                                     },
                                     para_update = function(iter, y, X, Z, Optim, printevery=100, verbose=TRUE) {
                                       # update Kmat and invKmat in the class environment
                                       stats <- c(0,0)
                                       invKmatList <- getinv_kernel(X,Z);

                                       if (iter==1) mean_solution(y)

                                       gradients <- grad_Matern_cpp(y, X, Z,
                                                                    Kmat, Karray,
                                                                    invKmatn, invKmatList$eigenval,
                                                                    parameters, stats, B, stdy)
                                       parameters <<- Optim$update(iter, parameters, gradients)

                                       mean_solution(y) # overwrites mu gradient update

                                       if ((iter %% printevery == 0)  && verbose) {
                                         cat(sprintf("%5d | log Evidence %9.4f | RMSE %9.4f | Norm. noise var: %3.4f | Gradient L2: %3.4f\n",
                                                     iter, stats[2], stats[1], exp(parameters[1]), norm(gradients)))
                                       }

                                       stats
                                     },
                                     get_train_stats = function(y, X, Z, invKmatList) {
                                       if(missing(invKmatList)){
                                         # do not update the inverse
                                         Klist <- kernel_mat_sym(X, Z)
                                         invKmatList <- invkernel_cpp(Klist$full, c(parameters[1]))
                                       }

                                       stats <- stats_cpp(y, Kmat, invKmatList$inv, invKmatList$eigenval, parameters[2], stdy)

                                     },
                                     mean_solution = function(y) {
                                       #using analytic solution
                                       parameters[2] <<- mu_solution_cpp(y, invKmatn)
                                     },
                                     predict = function(y, X, Z, X2, Z2, mean_y, std_y) {
                                       n2 <- nrow(X2)

                                       K_xX <- kernmat_Matern32_cpp(X2, X, Z2, Z, parameters)$full
                                       K_xx <- kernmat_Matern32_symmetric_cpp(X2, Z2, parameters)$full

                                       outlist <- pred_cpp(y, parameters[1], parameters[2],
                                                           invKmatn, K_xX, K_xx, mean_y, std_y)
                                     },
                                     predict_marginal = function(y, X, Z, X2, Z2, dZ2,
                                                                 mean_y, std_y, std_Z,
                                                                 calculate_ate){

                                       n <- length(y)
                                       n2 <- nrow(X2)

                                       Kmarginal_xX <- kernmat_Matern32_cpp(X2, X, dZ2, Z, parameters)$elements
                                       Kmarginal_xx <- kernmat_Matern32_symmetric_cpp(X2, dZ2, parameters)$elements

                                       outlist <- pred_marginal_cpp(y, Z2, parameters[1], parameters[2],
                                                                    invKmatn,
                                                                    Kmarginal_xX, Kmarginal_xx,
                                                                    mean_y, std_y, std_Z, calculate_ate)
                                     })
) # end class
