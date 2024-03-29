##############################################################################################################################
#' Flip a 1 and a 0 simultaneously
#'
#' @param x an integer or logical vector
#'
#' @return x an integer vector
#'
flip01 <- function(x) {
    #store index to prevent flipping the same bit again
    zeroIdxs <- which(x==0L)
    if (length(zeroIdxs) == 1) {
        idx0 <- zeroIdxs
    } else {
        idx0 <- sample(zeroIdxs, 1)
    }

    onesIdxs <- which(x==1L)
    if (length(onesIdxs) == 1) {
        idx1 <- onesIdxs
    } else {
        idx1 <- sample(onesIdxs, 1)
    }

    #flip the bits
    x[idx0] <- 1L; x[idx1] <- 0L

    x
} #flip01



##############################################################################################################################
#' Unpack constraints in a list of list into a matrix, equality or inequality signs, constant on right hand side
#'
#' @param constraints - a list of list of constraints with constr.mat, constr.dir, constr.rhs in each sublist
#'
#' @return a list containing matrix, signs and RHS constants
#'
#' @noRd
#'
unlist.constr <- function(constraints) {
    constr.mat = constr.dir = constr.rhs = NULL
    list(constr.mat=do.call(rbind, lapply(constraints, with, constr.mat)),
         constr.dir=do.call(c,     lapply(constraints, with, constr.dir)),
         constr.rhs=do.call(c,     lapply(constraints, with, constr.rhs))
         )
} #unlist.constr



##############################################################################################################################
#' Generate an initial feasible solution by solving a linear programming with binary variables
#'
#' @param numVar - number of variables
#' @param objVec - objective function as a numeric vector
#' @param constraints - a list of list of constraints with constr.mat, constr.dir, constr.rhs in each sublist
#'
#' @return a binary vector containing a feasible solution
#'
#' @examples
#' #see documentation for sampl.mcmc
#'
#' @import lpSolve
#' @importFrom stats runif
#'
#' @export
#'
initState <- function(numVar, objVec=runif(numVar), constraints=NULL) {
    constr <- unlist.constr(constraints)
    lp(direction="max",
        objective.in=objVec,
        const.mat=constr$constr.mat,
        const.dir=constr$constr.dir,
        const.rhs=constr$constr.rhs,
        all.bin=TRUE)$solution
} #initState



##############################################################################################################################
#' Generate feasible solutions to a knapsack problem using Markov Chain Monte Carlo
#'
#' @param init - an initial feasible solution
#' @param numSampl - number of samples to be generated
#' @param maxIter - maximum number of iterations to be run to prevent infinite loop
#' @param constraints - a list of list of constraints with constr.mat, constr.dir, constr.rhs in each sublist.
#'     Please see example for an example of constraints.
#' @return a matrix of \{0, 1\} with each row representing a sample
#'
#' @examples
#'
#' #number of variables
#' N <- 100
#'
#' #number of variables in each group
#' grpLen <- 10
#'
#' #equality matrix
#' A <- matrix(c(rep(1, N)), ncol=N, byrow=TRUE)
#'
#' #inequality matrix
#' G <- matrix(c(rep(1, grpLen), rep(0, N - grpLen),
#'     rep(c(0,1), each=grpLen), rep(0, N - 2*grpLen)), ncol=N, byrow=TRUE)
#'
#' #construct a list of list of constraints
#' constraints <- list(
#'     list(constr.mat=A, constr.dir=rep("==", nrow(A)), constr.rhs=c(20)),
#'     list(constr.mat=G, constr.dir=rep("<=", nrow(G)), constr.rhs=c(5, 5)),
#'     list(constr.mat=G, constr.dir=rep(">=", nrow(G)), constr.rhs=c(1, 2))
#' )
#'
#' #generate an initial feasible solution
#' init <- initState(N, constraints=constraints)
#'
#' #create feasible solutions to knapsack problems subject to constraints
#' samples <- sampl.mcmc(init, 50, constraints=constraints)
#'
#' @export
#'
sampl.mcmc <- function(init, numSampl, maxIter=2*numSampl, constraints=NULL) {
    n <- 0; cnt <- 0; x <- init; res <- list()
    constr <- unlist.constr(constraints)
    dirns <- lapply(constr$constr.dir, get)

    while(cnt < numSampl && n < maxIter) {
        #clip a 0 and 1 bit sample simultaneously
        y <- flip01(x)
        feasible <- TRUE

        #check constraints
        if (!is.null(constraints)) {
            #evaluate A * x first
            evalRHS <- (constr$constr.mat %*% y)[,1]

            #check A * x against rhs
            checkconstr <- vapply(1:length(dirns),
                function(i) dirns[[i]](evalRHS[i], constr$constr.rhs[i]),
                logical(1))

            #all constraints must be satisified
            feasible <- all(checkconstr)
        }

        if (feasible) {
            #transition to next state
            x <- y

            #store sample
            res[[cnt+1]] <- y

            #increment count
            cnt <- cnt + 1
        }

        n <- n + 1
    } #while we still need more samples

    do.call(rbind, res)
} #sampl.mcmc
