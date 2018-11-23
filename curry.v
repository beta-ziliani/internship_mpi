From Mtac2 Require Import Base Mtac2 Sorts MTele.
Import Sorts.S.
Import M.notations.
Import M.M.

Local Notation MFA T := (MTele_val (MTele_C SType SProp M T)).
Local Notation InF s n := (forall now_ty : forall s0 : Sort, MTele_Sort s0 n -> s0, (forall (s0 : Sort) (T : MTele_Sort s0 n), MTele_val T -> now_ty s0 T) -> s).

(* If recursion is needed then it's TyTree, if not only Type *)
Inductive TyTree : Type :=
| tyTree_val {m : MTele} (T : MTele_Ty m) : TyTree
| tyTree_M (T : Type) : TyTree
| tyTree_MFA {m : MTele} (T : MTele_Ty m) : TyTree
| tyTree_In (s : Sort) {m : MTele} (F : InF s m) : TyTree
| tyTree_imp (T : TyTree) (R : TyTree) : TyTree
| tyTree_FATele {m : MTele} (T : MTele_Ty m) (F : forall t : MTele_val T, TyTree) : TyTree
| tyTree_FA (T : Type) (F : T -> TyTree) : TyTree
| tyTree_FAType (F : Type -> TyTree) : TyTree
| tyTree_base (T : Type) : TyTree
.

Fixpoint tree_ty (X : TyTree) : Type :=
  match X as X' with
  | tyTree_val T => MTele_val T
  | tyTree_M T => M T
  | tyTree_MFA T => MFA T
  | tyTree_In s F => MTele_val (MTele_In s F)
  | tyTree_imp T R => tree_ty T -> tree_ty R
  | @tyTree_FATele m T F => forall T, tree_ty (F T)
  | tyTree_FA T F => forall t : T, tree_ty (F t)
  | tyTree_FAType F => forall T : Type, tree_ty (F T)
  | tyTree_base T => T
  end.

Definition ty_tree (X : Type) : M TyTree :=
  (mfix1 rec (X : Type) : M TyTree :=
    mmatch X as X return M TyTree with
    (* | [? (m : MTele) (T : MTele_Ty m)] MTele_val T =>
       ret (tyTree_val p T) (* fail *) *)
    | [? T : Type] (M T):Type =>
      ret (tyTree_M T)
    (* | [? (m : MTele) (T : MTele_Ty m)] (MFA T):Type =>
      ret (tyTree_MFA T) (* fail *) *)
    | [? T R : Type] T -> R =>
      T <- rec T ;
      R <- rec R;
      ret (tyTree_imp T R)
    (* | [? (m : MTele) (T : MTele_Ty m) (F : forall x : MTele_val T, Type)] forall T , F T =>
      \nu t : _,
        F <- rec (F t) p;
        F <- abs_fun t F;
        ret (tyTree_FATele p T F) (* fail *) *)
    | [? F : Type -> Type] forall T : Type, F T =>
      \nu T : Type,
        F <- rec (F T);
        F <- abs_fun T F;
        ret (tyTree_FAType F)
    | [? T (F : forall t : T, Type)] forall t : T, F t =>
      \nu t : T,
        F <- rec (F t);
        F <- abs_fun t F;
        ret (tyTree_FA T F)
    | _ => ret (tyTree_base X)
    end) X.

Definition ty_tree' {X : Type} (x : X) := ty_tree X.

(* pol means polarity at that point of the tree *)
(* We don't want the M at the return type *)
Fixpoint checker (pol : bool) (X : TyTree) : Prop :=
  match X as X' with
  (* direct telescope cases *)
  | tyTree_val T =>
    match negb pol with
    | true => True
    | false => False
    end
  | tyTree_MFA T =>
    match negb pol with
    | true => True
    | false => False
    end
  | tyTree_In s F =>
    match negb pol with
    | true => True
    | false => False
    end
  | @tyTree_FATele m T F => forall t : MTele_val T, (checker pol (F t))
  (* non-telescope cases *)
  | tyTree_M T => True
  | tyTree_base T => True
  (* indirect cases *)
  | tyTree_imp T R => match checker (negb pol) T with
                     | True => checker pol R
                     end
  | tyTree_FA T F => forall t : T, checker pol (F t)
  | tyTree_FAType F => forall T : Type, checker pol (F T)
  end.


Goal TyTree.
mrun (ty_tree' (@ret)).
Show Proof.

Goal TyTree.
mrun (ty_tree'(@bind)).
Show Proof.

Goal TyTree.
mrun (ty_tree (forall (m : MTele) (A B : MTele_Ty m), MFA A -> (MTele_val A -> MFA B) -> MFA B)).
Show Proof.

Notation "'[withP' now_ty , now_val '=>' t ]" :=
  (MTele_In (SProp) (fun now_ty now_val => t))
  (at level 0, format "[withP now_ty , now_val => t ]").

Eval compute in (tree_ty (tyTree_base nat)).
Eval compute in (tree_ty (tyTree_FAType (fun T : Type => tyTree_imp (tyTree_base T) (tyTree_M T)))).

Eval compute in (checker true (tyTree_FAType (fun T : Type => tyTree_imp (tyTree_base T) (tyTree_M T)))).
Eval compute in (checker true (tyTree_FA MTele
   (fun t0 : MTele =>
    tyTree_FA (MTele_Ty t0)
      (fun t1 : MTele_Ty t0 =>
       tyTree_FA (MTele_Ty t0)
         (fun t2 : MTele_Ty t0 =>
          tyTree_imp (tyTree_MFA t1)
            (tyTree_imp
               (tyTree_imp (tyTree_val t1)
                  (tyTree_MFA t2)) (tyTree_MFA t2))))))).