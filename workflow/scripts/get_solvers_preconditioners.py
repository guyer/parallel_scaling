"""Introspect FiPy for names of solvers and preconditioners in active suite
"""

import argparse
import json

parser = argparse.ArgumentParser(
                    prog='get_solvers_preconditioners',
                    description='Store lists of solvers and preconditioners in active solver suite')
parser.add_argument('solver_fname')
parser.add_argument('preconditioner_fname')
args = parser.parse_args()

import fipy as fp

def get_classes(cls):
    classes = []

    for k, v in fp.solvers.__dict__.items():
        if (isinstance(v, type)
            and issubclass(v, cls)):
                classes.append(k)

    return classes

if __name__ == "__main__":
    solvers = get_classes(cls=fp.solver.Solver)
    exclude = ["Solver", "DefaultSolver", "DefaultAsymmetricSolver",
               "DummySolver", "GeneralSolver", "TrilinosMLTest"]
    solvers = [solver for solver in solvers if solver not in exclude]

    with open(args.solver_fname, 'w') as f:
        json.dump({"solver": solvers}, f)

    preconditioners = get_classes(cls=fp.preconditioner.Preconditioner)
    preconditioners.append("none")

    with open(args.preconditioner_fname, 'w') as f:
        json.dump({"preconditioner": preconditioners}, f)
