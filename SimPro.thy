theory SimPro imports Main begin

type_synonym proxy = nat

datatype form = Pos string "nat list" | Con form form | Uni form
              | Neg string "nat list" | Dis form form | Exi form

type_synonym model = "proxy set \<times> (string \<Rightarrow> proxy list \<Rightarrow> bool)"

type_synonym environment = "nat \<Rightarrow> proxy"

definition is_model_environment :: "model \<Rightarrow> environment \<Rightarrow> bool"
where
  "is_model_environment m e = (\<forall>x. e x \<in> fst m)"

primrec semantics :: "model \<Rightarrow> environment \<Rightarrow> form \<Rightarrow> bool"
where
  "semantics m e (Pos p l) = snd m p (map e l)"
| "semantics m e (Neg p l) = (\<not> snd m p (map e l))"
| "semantics m e (Con f g) = (semantics m e f \<and> semantics m e g)"
| "semantics m e (Dis f g) = (semantics m e f \<or> semantics m e g)"
| "semantics m e (Uni f) = (\<forall>x \<in> fst m. semantics m (\<lambda>y. case y of 0 \<Rightarrow> x | Suc n \<Rightarrow> e n) f)"
| "semantics m e (Exi f) = (\<exists>x \<in> fst m. semantics m (\<lambda>y. case y of 0 \<Rightarrow> x | Suc n \<Rightarrow> e n) f)"

primrec SEval :: "model \<Rightarrow> environment \<Rightarrow> form list \<Rightarrow> bool"
where
  "SEval m e [] = False"
| "SEval m e (h#t) = (semantics m e h \<or> SEval m e t)"

definition Svalid :: "form list \<Rightarrow> bool"
where
  "Svalid s = (\<forall>m e. is_model_environment m e \<longrightarrow> SEval m e s)"

primrec preSuc :: "nat list \<Rightarrow> nat list"
where
  "preSuc [] = []"
| "preSuc (h#t) = (case h of 0 \<Rightarrow> preSuc t | Suc n \<Rightarrow> n#(preSuc t))"

primrec fv :: "form \<Rightarrow> nat list"
where
  "fv (Pos p l) = l"
| "fv (Neg p l) = l"
| "fv (Con f g) = fv f @ fv g"
| "fv (Dis f g) = fv f @ fv g"
| "fv (Uni f) = preSuc (fv f)"
| "fv (Exi f) = preSuc (fv f)"

primrec subst :: "(nat \<Rightarrow> nat) \<Rightarrow> form \<Rightarrow> form"
where
  "subst r (Pos p l) = Pos p (map r l)"
| "subst r (Neg p l) = Neg p (map r l)"
| "subst r (Con f g) = Con (subst r f) (subst r g)"
| "subst r (Dis f g) = Dis (subst r f) (subst r g)"
| "subst r (Uni f) = Uni (subst (\<lambda>y. case y of 0 \<Rightarrow> 0 | Suc n \<Rightarrow> Suc (r n)) f)"
| "subst r (Exi f) = Exi (subst (\<lambda>y. case y of 0 \<Rightarrow> 0 | Suc n \<Rightarrow> Suc (r n)) f)"

definition finst :: "form \<Rightarrow> nat \<Rightarrow> form"
where
  "finst f x = (subst (\<lambda>y. case y of 0 \<Rightarrow> x | Suc n \<Rightarrow> n) f)"

primrec flatten :: "'a list list \<Rightarrow> 'a list"
where
  "flatten [] = []"
| "flatten (h#t) = h @ flatten t"

definition fv_list :: "form list \<Rightarrow> nat list"
where
  "fv_list s = flatten (map fv s)"

primrec maxvar :: "nat list \<Rightarrow> nat"
where
  "maxvar [] = 0"
| "maxvar (h#t) = max h (maxvar t)"

definition newvar :: "nat list \<Rightarrow> nat"
where
  "newvar l = (if l = [] then 0 else Suc (maxvar l))"

primrec member :: "'a => 'a list => bool"
where
  "member a [] = False"
| "member a (h#t) = (if a = h then True else member a t)"

type_synonym sequent = "(nat \<times> form) list"

definition make_sequent :: "form list \<Rightarrow> sequent"
where
  "make_sequent l = map (\<lambda>f. (0,f)) l"

definition list_sequent :: "sequent \<Rightarrow> form list"
where
  "list_sequent s = map snd s"

primrec subs :: "sequent \<Rightarrow> sequent list"
where
  "subs [] = [[]]"
| "subs (h#t) = (let (n,f) = h in
     case f of
       Pos p l \<Rightarrow> if member (Neg p l) (list_sequent t) then [] else [t @ [(0,Pos p l)]]
     | Neg p l \<Rightarrow> if member (Pos p l) (list_sequent t) then [] else [t @ [(0,Neg p l)]]
     | Con f g \<Rightarrow> [t @ [(0,f)],t @ [(0,g)]]
     | Dis f g \<Rightarrow> [t @ [(0,f),(0,g)]]
     | Uni f \<Rightarrow> [t @ [(0,finst f (newvar (fv_list (list_sequent (h#t)))))]]
     | Exi f \<Rightarrow> [t @ [(0,finst f n),(Suc n,Exi f)]]
   )"

inductive_set deriv :: "sequent \<Rightarrow> (nat \<times> sequent) set"
for s :: sequent
where
  init[intro]: "(0,s) \<in> deriv s"
| step[intro]: "(n,l) \<in> deriv s \<Longrightarrow> l' \<in> set (subs l) \<Longrightarrow> (Suc n,l') \<in> deriv s"

proposition "Svalid s = finite (deriv (make_sequent s))" oops

lemma "is_model_environment m e \<Longrightarrow> fst m \<noteq> {}"
  using is_model_environment_def by auto

lemma "\<exists>m. \<forall>e. is_model_environment m e \<and> infinite (fst m)"
  using is_model_environment_def infinite_UNIV_nat by auto

primrec is_axiom :: "form list \<Rightarrow> bool"
where
  "is_axiom [] = False"
| "is_axiom (a#list) = ((? p l. a = Pos p l & Neg p l : set list) | (? p l. a = Neg p l & Pos p l : set list))"

lemma mm[simp]: "member a l = (a : (set l))" by (induct l) auto

lemma patom:  "(n,(m,Pos p l)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Pos p l)#xs)) \<Longrightarrow> (Suc n,xs@[(0,Pos p l)]) \<in> deriv(nfs)"
  and natom:  "(n,(m,Neg p l)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Neg p l)#xs)) \<Longrightarrow> (Suc n,xs@[(0,Neg p l)]) \<in> deriv(nfs)"
  and fconj1: "(n,(m,Con f g)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Con f g)#xs)) \<Longrightarrow> (Suc n,xs@[(0,f)]) \<in> deriv(nfs)"
  and fconj2: "(n,(m,Con f g)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Con f g)#xs)) \<Longrightarrow> (Suc n,xs@[(0,g)]) \<in> deriv(nfs)"
  and fdisj:  "(n,(m,Dis f g)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Dis f g)#xs)) \<Longrightarrow> (Suc n,xs@[(0,f),(0,g)]) \<in> deriv(nfs)"
  and fall:   "(n,(m,Uni f)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Uni f)#xs)) \<Longrightarrow> (Suc n,xs@[(0,finst f (newvar (fv_list (list_sequent ((m,Uni f)#xs)))))]) \<in> deriv(nfs)"
  and fex:    "(n,(m,Exi f)#xs) \<in> deriv(nfs) \<Longrightarrow> ~is_axiom (list_sequent ((m,Exi f)#xs)) \<Longrightarrow> (Suc n,xs@[(0,finst f m),(Suc m,Exi f)]) \<in> deriv(nfs)"
  by (auto simp add: Let_def list_sequent_def)

lemmas not_is_axiom_subs = patom natom fconj1 fconj2 fdisj fall fex

lemma deriv0[simp]: "(0,x) \<in> deriv y = (x = y)"
  using deriv.cases by blast

lemma deriv_upwards: "(n,list) \<in> deriv s \<Longrightarrow> ~ is_axiom (list_sequent (list)) \<Longrightarrow> (\<exists>zs. (Suc n, zs) \<in> deriv s & zs : set (subs list))"
  apply(case_tac list) apply force
  apply(case_tac a) apply(case_tac b)
       apply(simp add: Let_def) apply(rule) apply(simp add: list_sequent_def) apply(force dest: not_is_axiom_subs)
     apply(simp add: Let_def) apply(force dest: not_is_axiom_subs)
    apply(simp add: Let_def) apply(force dest: not_is_axiom_subs)
      apply(simp add: Let_def) apply(rule) apply(simp add: list_sequent_def) apply(force dest: not_is_axiom_subs)
   apply(simp add: Let_def) apply(force dest: not_is_axiom_subs)
  apply(simp add: Let_def) apply(force dest: not_is_axiom_subs)
  done

lemma deriv_downwards: "(Suc n, x) \<in> deriv s \<Longrightarrow> \<exists>y. (n,y) \<in> deriv s & x : set (subs y) & ~ is_axiom (list_sequent y)"
  apply(erule deriv.cases)
  apply(simp)
  apply(simp add: list_sequent_def Let_def)
  apply(rule_tac x=l in exI) apply(simp)
  apply(case_tac l) apply(simp)
  apply(case_tac a) apply(case_tac b) 
       apply(auto simp add: Let_def)
   apply (rename_tac[!] nat lista a)
apply(simp only: list_sequent_def)
   apply(subgoal_tac "Neg nat lista \<in> snd ` set list") apply(simp) apply(force)
  apply(subgoal_tac "Pos nat lista \<in> snd ` set list")
apply(simp only: list_sequent_def)
apply(simp) apply(force)
  done

lemma deriv_deriv_child[rule_format]: "\<forall>x y. (Suc n,x) \<in> deriv y = (\<exists>z. z : set (subs y) & ~ is_axiom (list_sequent y) & (n,x) \<in> deriv z)"
  apply(induct n)
   apply(rule, rule) apply(rule) apply(frule_tac deriv_downwards) apply(simp)
   apply(simp) apply(rule step) apply(simp) apply(simp)
  apply(blast dest!: deriv_downwards elim: deriv.cases) -- "blast needs some help with the reasoning, hence derivSucE"
  done

lemma deriv_progress: "(n,a#list) \<in> deriv s \<Longrightarrow> ~ is_axiom (list_sequent (a#list)) \<Longrightarrow> (\<exists>zs. (Suc n, list@zs) \<in> deriv s)"
  apply(subgoal_tac "a#list \<noteq> []") prefer 2 apply(simp)
  apply(case_tac a) apply(case_tac b)
       apply(force dest: not_is_axiom_subs)+
  done

definition
  inc :: "nat \<times> sequent \<Rightarrow> nat \<times> sequent" where
  "inc = (%(n,fs). (Suc n, fs))"

lemma inj_inc[simp]: "inj inc"
  by (simp add: inc_def inj_on_def)

lemma deriv: "deriv y = insert (0,y) (inc ` (Union (deriv ` {w. ~is_axiom (list_sequent y) & w : set (subs y)})))"
  apply(rule set_eqI)
  apply(simp add: split_paired_all)
  apply(case_tac a)
   apply(force simp: inc_def)
  apply(force simp: deriv_deriv_child inc_def)
  done

lemma deriv_is_axiom: "is_axiom (list_sequent s) \<Longrightarrow> deriv s = {(0,s)}"
  apply(rule)
   apply(rule)
   apply(case_tac x) apply(simp)
   apply(erule_tac deriv.induct) apply(force) apply(simp_all add: list_sequent_def) apply(case_tac s) apply(simp) apply(case_tac aa) apply(case_tac ba)
         apply(simp_all add: Let_def list_sequent_def)
  done
   
lemma is_axiom_finite_deriv: "is_axiom (list_sequent s) \<Longrightarrow> finite (deriv s)"
  by (simp add: deriv_is_axiom)

subsection "Failing path"

primrec failing_path :: "(nat \<times> sequent) set \<Rightarrow> nat \<Rightarrow> (nat \<times> sequent)"
where
  "failing_path ns 0 = (SOME x. x \<in> ns & fst x = 0 & infinite (deriv (snd x)) & ~ is_axiom (list_sequent (snd x)))"
| "failing_path ns (Suc n) = (let fn = failing_path ns n in 
  (SOME fsucn. fsucn \<in> ns & fst fsucn = Suc n & (snd fsucn) : set (subs (snd fn)) & infinite (deriv (snd fsucn)) & ~ is_axiom (list_sequent (snd fsucn))))"

locale loc1 =
  fixes s and f
  assumes f: "f = failing_path (deriv s)"

lemma (in loc1) f0: "infinite (deriv s) \<Longrightarrow> f 0 \<in> (deriv s) & fst (f 0) = 0 & infinite (deriv (snd (f 0))) & ~ is_axiom (list_sequent (snd (f 0)))"
  by (simp add: f) (metis (mono_tags, lifting) deriv.init is_axiom_finite_deriv fst_conv snd_conv someI_ex)

lemma infinite_union: "finite Y \<Longrightarrow> infinite (Union (f ` Y)) \<Longrightarrow> \<exists>y. y \<in> Y & infinite (f y)"
  by auto

lemma infinite_inj_infinite_image: "inj_on f Z \<Longrightarrow> infinite (f ` Z) = infinite Z"
  by (auto dest: finite_imageD)

lemma inj_inj_on: "inj f \<Longrightarrow> inj_on f A"
  by (blast intro: subset_inj_on)

lemma t: "finite {w. P w} \<Longrightarrow> finite {w. Q w & P w}"
  by (simp add: finite_subset)

lemma finite_subs: "finite {w. ~is_axiom (list_sequent y) & w : set (subs y)}"
  by simp

lemma (in loc1) fSuc: "f n \<in> deriv s & fst (f n) = n & infinite (deriv (snd (f n))) & ~is_axiom (list_sequent (snd (f n)))
  \<Longrightarrow> f (Suc n) \<in> deriv s & fst (f (Suc n)) = Suc n & (snd (f (Suc n))) : set (subs (snd (f n))) & infinite (deriv (snd (f (Suc n)))) & ~is_axiom (list_sequent (snd (f (Suc n))))"
  apply(simp add: Let_def f)
  apply(rule_tac someI_ex)
  apply(simp only: f[symmetric]) 
  apply(drule_tac subst[OF deriv[of "snd (f n)"] ])
  apply(simp only: finite_insert) apply(subgoal_tac "infinite (\<Union>(deriv ` {w. ~is_axiom (list_sequent (snd (f n))) & w : set (subs (snd (f n)))}))")
   apply(drule_tac infinite_union[OF finite_subs]) apply(erule exE) apply(rule_tac x="(Suc n, y)" in exI)
   apply(clarify) apply(simp) apply(case_tac "f n") apply(simp add: step) apply(force simp add: is_axiom_finite_deriv)
  apply(force simp add: infinite_inj_infinite_image inj_inj_on) 
  done

lemma (in loc1) is_path_f_0: "infinite (deriv s) \<Longrightarrow> f 0 = (0,s)"
  apply(subgoal_tac "f 0 \<in> deriv s & fst (f 0) = 0")
   prefer 2 apply(frule_tac f0) apply(simp)
  apply(case_tac "f 0") apply(elim conjE, simp)
  done

lemma (in loc1) is_path_f': "infinite (deriv s) \<Longrightarrow> f n \<in> deriv s & fst (f n) = n & infinite (deriv (snd (f n))) & ~ is_axiom (list_sequent (snd (f n)))"
  by (induct n) (auto simp add: f0 fSuc)

lemma (in loc1) is_path_f: "infinite (deriv s) \<Longrightarrow> \<forall>n. f n \<in> deriv s & fst (f n) = n & (snd (f (Suc n))) : set (subs (snd (f n))) & infinite (deriv (snd (f n)))"
  by (simp add: is_path_f' fSuc)

subsection "Models"

lemma ball_eq_ball: "\<forall>x \<in> m. P x = Q x \<Longrightarrow> (\<forall>x \<in> m. P x) = (\<forall>x \<in> m. Q x)"
  by blast

lemma bex_eq_bex: "\<forall>x \<in> m. P x = Q x \<Longrightarrow> (\<exists>x \<in> m. P x) = (\<exists>x \<in> m. Q x)"
  by blast

lemma preSuc[simp]:"Suc n \<in> set A = (n \<in> set (preSuc A))"
  by (induct A) (simp, case_tac a, simp_all)

lemma FEval_cong: "\<forall>e1 e2. (\<forall>xx. xx \<in> set (fv A) \<longrightarrow> e1 xx = e2 xx) \<longrightarrow> semantics mi e1 A = semantics mi e2 A"
  apply(induct_tac A)
       apply(simp add: Let_def ) apply(intro allI impI) apply(rule arg_cong, rule map_cong) apply(rule) apply(force)
     apply(simp add: Let_def ) apply(intro allI impI) apply(rule conj_cong) apply(force) apply(force)
   apply(simp add: Let_def ) apply(intro allI impI) apply(rule ball_eq_ball) apply(rule) 
   apply(drule_tac x="case_nat xa e1" in spec) apply(drule_tac x="case_nat xa e2" in spec) apply(erule impE)
    apply(rule) apply(rule) apply(rename_tac x) apply(case_tac x) apply(simp) apply(simp)
   apply(assumption)
      apply(simp add: Let_def ) apply(intro allI impI) apply(rule arg_cong, rule map_cong) apply(rule)  apply(force)
    apply(simp add: Let_def ) apply(intro allI impI) apply(rule disj_cong) apply(force) apply(force)
  apply(simp add: Let_def ) apply(intro allI impI) apply(rule bex_eq_bex) apply(rule)
  apply(drule_tac x="case_nat xa e1" in spec) apply(drule_tac x="case_nat xa e2" in spec) apply(erule impE)
   apply(rule) apply(rule) apply(rename_tac x) apply(case_tac x) apply(simp) apply(simp)
  apply(assumption)
  done

lemma SEval_def2: "SEval m e s = (\<exists>f. f \<in> set s & semantics m e f)"
  by (induct s) auto

lemma SEval_append: "SEval m e (xs@ys) = ( (SEval m e xs) | (SEval m e ys))"
  by (induct xs) auto

lemma all_eq_all: "\<forall>x. P x = Q x \<Longrightarrow> (\<forall>x. P x) = (\<forall>x. Q x)"
  by blast

lemma fv_list_nil: "fv_list [] = []"
  by (simp add: fv_list_def)

lemma fv_list_cons: "fv_list (a#list) = (fv a) @ (fv_list list)"
  by (simp add: fv_list_def)

lemma SEval_cong: "(\<forall>x. x \<in> set (fv_list s) \<longrightarrow> e1 x = e2 x) \<longrightarrow> SEval m e1 s = SEval m e2 s"
  by (induct s) (simp, metis FEval_cong SEval.simps(2) Un_iff set_append fv_list_cons)

subsection "Soundness"

lemma fold_compose1: "(% x. f (g x)) = (f o g)" 
  by auto

lemma FEval_subst: "\<forall>e f. (semantics mi e (subst f A)) = (semantics mi (e o f) A)"
  apply(induct A)
       apply(simp add: Let_def) apply(simp only: fold_compose1) apply(blast)
    apply(simp)
   apply(simp) apply(rule,rule) apply(rule ball_eq_ball) apply(rule)
   apply(subgoal_tac "(%u. case_nat x e (case u of 0 \<Rightarrow> 0 | Suc n \<Rightarrow> Suc (f n))) = (case_nat x (%n. e (f n)))") apply(simp)
   apply(rule ext) apply(case_tac u)
    apply(simp) apply(simp)
      apply(simp add: Let_def) apply(simp only: fold_compose1) apply(blast)
     apply(simp)
  apply(simp) apply(rule,rule) apply(rule bex_eq_bex) apply(rule)
  apply(subgoal_tac "(%u. case_nat x e (case u of 0 \<Rightarrow> 0 | Suc n \<Rightarrow> Suc (f n))) = (case_nat x (%n. e (f n)))") apply(simp)
  apply(rule ext) apply(case_tac u)
   apply(simp) apply(simp)
  done

lemma FEval_finst: "semantics mo e (finst A u) = semantics mo (case_nat (e u) e) A"
  apply(simp add: finst_def)
  apply(simp add: FEval_subst)
  apply(subgoal_tac "(e o case_nat u (%n. n)) = (case_nat (e u) e)") apply(simp)
  apply(rule ext)
  apply(case_tac x, auto)
  done

lemma ball_maxscope: "(\<forall>x \<in> m. P x | Q) \<Longrightarrow> (\<forall>x \<in> m. P x) | Q "
  by simp

lemma sound_FAll: "u \<notin> set (fv_list (Uni f#s)) \<Longrightarrow> Svalid (s@[finst f u]) \<Longrightarrow> Svalid (Uni f#s)"
  apply(simp add: Svalid_def del: SEval.simps)
  apply(rule allI) 
  apply(rule allI)
  apply(rename_tac M I)
  apply(rule allI) apply(rule)
  apply(simp)
  apply(simp add: SEval_append)
  apply(rule ball_maxscope)
  apply(rule)
  apply(simp add: FEval_finst)

  apply(drule_tac x=M in spec, drule_tac x=I in spec) -- "this is the goal"

  apply(drule_tac x="e(u:=x)" in spec) apply(erule impE) apply(simp add: is_model_environment_def) apply(erule disjE)
   apply(rule disjI2)
   apply(subgoal_tac "SEval (M,I) (e(u :=x)) s = SEval (M,I) e s")
    apply(simp)
   apply(rule SEval_cong[rule_format]) apply(simp add: fv_list_cons) apply(force)

  apply(rule disjI1)
  apply(simp)
  apply(subgoal_tac "semantics (M,I) (case_nat x (e(u :=x))) f = semantics (M,I) (case_nat x e) f")
   apply(simp)
  apply(rule FEval_cong[rule_format])

  apply(case_tac xx, simp)
  apply(simp)
  apply(simp only: preSuc[rule_format, symmetric])
  apply(subgoal_tac "nat \<in> set (fv (Uni f))") prefer 2 apply(simp)
  
  apply(force simp: fv_list_cons)
  done
    -- "phew, that really was a bit more difficult than expected"
    -- "note that we can avoid maxscoping at the cost of instantiating the hyp twice- an additional time for M"
    -- "different proof, instantiating quantifier twice, avoiding maxscoping --- not much better, probably slightly worse"

lemma sound_FEx: "Svalid (s@[finst f u,Exi f]) \<Longrightarrow> Svalid (Exi f#s)"
  apply(simp add: Svalid_def del: SEval.simps)
  apply(rule allI)
  apply(rule allI)
  apply(rename_tac ms m)
  apply(rule) apply(rule)
  apply(simp)
  apply(simp add: SEval_append)
  apply(simp add: FEval_finst)

  apply(drule_tac x=ms in spec, drule_tac x=m in spec)
  apply(drule_tac x=e in spec) apply(erule impE) apply(assumption)
  apply(erule disjE)
  apply(simp)
  apply(erule disjE)
   apply(rule disjI1)
   apply(rule_tac x="e u" in bexI) apply(simp) apply(simp add: is_model_environment_def)
  apply(force)
  done

lemma max_exists: "finite (X::nat set) \<Longrightarrow> X \<noteq> {} \<longrightarrow> (\<exists>x. x \<in> X & (\<forall>y. y \<in> X \<longrightarrow> y \<le> x))"
  apply(erule_tac finite_induct) 
  apply(force)
  apply(rule)
  apply(case_tac "F = {}")
  apply(force)
  apply(erule impE) apply(force)
  apply(elim exE conjE)
  apply(rule_tac x="max x xa" in exI)
  apply(rule) apply(simp add: max_def)
  apply(simp add: max_def) apply(force)
  done
  -- "poor max lemmas in lib"

lemma inj_finite_image_eq_finite: "inj_on f Z \<Longrightarrow> finite (f ` Z) = finite Z"
  by (blast intro: finite_imageD)

lemma finite_inc: "finite (inc ` X) = finite X"
  by (metis finite_imageI inj_inc inv_image_comp)

lemma finite_deriv_deriv: "finite (deriv s) \<Longrightarrow> finite  (deriv ` {w. ~is_axiom (list_sequent s) & w : set (subs s)})"
  by simp

definition
  init :: "sequent \<Rightarrow> bool" where
  "init s = (\<forall>x \<in> (set s). fst x = 0)"

definition
  is_FEx :: "form \<Rightarrow> bool" where
  "is_FEx f = (case f of
      Pos p l \<Rightarrow> False
    | Neg p l \<Rightarrow> False
    | Con f g \<Rightarrow> False
    | Dis f g \<Rightarrow> False
    | Uni f \<Rightarrow> False
    | Exi f \<Rightarrow> True)"

lemma is_FEx[simp]: "~ is_FEx (Pos p l)
  & ~ is_FEx (Neg p l)
  & ~ is_FEx (Con f g)
  & ~ is_FEx (Dis f g)
  & ~ is_FEx (Uni f)"
  by (simp add: is_FEx_def)

lemma index0: "init s \<Longrightarrow> \<forall>u m A. (n, u) \<in> deriv s \<longrightarrow> (m,A) \<in> (set u) \<longrightarrow> (~ is_FEx A) \<longrightarrow> m = 0"
  apply(induct_tac n)
  apply(rule,rule,rule,rule,rule,rule) apply(simp) apply(force simp add: init_def)
  apply(rule,rule,rule,rule,rule,rule)
  -- {*inversion on @{term "(Suc n, u) \<in> deriv s"}*}
  apply(drule_tac deriv_downwards) apply(elim exE conjE)
  apply(case_tac y) apply(simp)
  apply(case_tac a) apply(case_tac b)
       apply(force simp add: Let_def list_sequent_def)
      apply(force simp add: Let_def list_sequent_def)
     apply(force simp add: Let_def list_sequent_def)
    apply(force simp add: Let_def list_sequent_def)
   apply(force simp add: Let_def list_sequent_def)
  apply(force simp add: is_FEx_def Let_def list_sequent_def)
  done

lemma maxvar: "\<forall>v \<in> set l. v \<le> maxvar l"
  by (induct l) (auto simp add: max_def)

lemma newvar: "newvar l \<notin> (set l)"
  using length_pos_if_in_set maxvar newvar_def by force

lemma soundness': "init s \<Longrightarrow> finite (deriv s) \<Longrightarrow> m \<in> (fst ` (deriv s)) \<Longrightarrow> \<forall>y u. (y,u) \<in> (deriv s) \<longrightarrow> y \<le> m \<Longrightarrow> \<forall>n t. h = m - n & (n,t) \<in> deriv s \<longrightarrow> Svalid (list_sequent t)"
  apply(induct_tac h)
    -- "base case"
   apply(simp) apply(rule,rule,rule) apply(elim conjE)
   apply(subgoal_tac "n=m") prefer 2 apply(force)
   apply(simp)
   apply(simp add: Svalid_def) apply(rule,rule) apply(rename_tac gs g) apply(rule) apply(rule) apply(simp add: SEval_def2)
   apply(case_tac "is_axiom (list_sequent t)")
     -- "base case, is axiom"
    apply(simp add: list_sequent_def) apply(case_tac t) apply(simp) apply(simp)
    apply(erule disjE) 
      -- "base case, is axiom, starts with Pos"
     apply(elim conjE exE)
     apply(subgoal_tac "semantics (gs,g) e (Pos p l) | semantics (gs,g) e (Neg p l)")
      apply(erule disjE) apply(force) apply(rule_tac x="Neg p l" in exI) apply(force)
     apply(simp add: Let_def)
      -- "base case, is axiom, starts with Neg"
    apply(elim conjE exE)
    apply(subgoal_tac "semantics (gs,g) e (Pos p l) | semantics (gs,g) e (Neg p l)")
      apply(erule disjE) apply(rule_tac x="Pos p l" in exI) apply(force) apply(force)
    apply(simp add: Let_def) 
    
    -- "base case, not is axiom: if not a satax, then subs holds... but this can't be"
   apply(drule_tac deriv_upwards) apply(assumption) apply(elim conjE exE) apply(force) 
   
     -- "step case, by case analysis"

  apply(intro allI impI) apply(elim exE conjE)

  apply(case_tac "is_axiom (list_sequent t)")
    -- "step case, is axiom"
  apply(simp add: Svalid_def) apply(rule,rule) apply(rename_tac gs g) apply(rule) apply(rule) apply(simp add: SEval_def2)
    apply(simp add: list_sequent_def) apply(case_tac t) apply(simp) apply(simp)
    apply(erule disjE)
     apply(elim conjE exE)
     apply(subgoal_tac "semantics (gs,g) e (Pos p l) | semantics (gs,g) e (Neg p l)")
      apply(erule disjE) apply(force) apply(rule_tac x="Neg p l" in exI) apply(blast)
     apply(simp add: Let_def)
    apply(elim conjE exE)
    apply(subgoal_tac "semantics (gs,g) e (Pos p l) | semantics (gs,g) e (Neg p l)")
      apply(erule disjE) apply(rule_tac x="Pos p l" in exI) apply(blast) apply(simp) apply(force)
    apply(simp add: Let_def)

     -- "we hit Uni/ Exi cases first"
  
  apply(case_tac "\<exists>(a::nat) f list. t = (a,Uni f)#list")
   apply(elim exE) apply(simp)
   apply(subgoal_tac "a = 0")
    prefer 2 
    apply(rule_tac n=na and u=t and A="Uni f" in index0[rule_format])
    apply(assumption) apply(simp) apply(simp) apply(simp)
   apply(frule_tac deriv.step) apply(simp add: Let_def)  -- "nice use of simp to instantiate"
   apply(drule_tac x="Suc na" in spec, drule_tac x="list @ [(0, finst f (newvar (fv_list (list_sequent t))))]" in spec) apply(erule impE, simp)
   apply(subgoal_tac "newvar (fv_list (list_sequent t)) \<notin> set (fv_list (list_sequent t))") 
    prefer 2 apply(rule newvar)
   apply(simp)
   apply(simp add: list_sequent_def)
   apply(frule_tac sound_FAll) apply(simp) apply(simp)
  
  apply(case_tac "\<exists>a f list. t = (a,Exi f)#list")
   apply(elim exE)
   apply(frule_tac deriv.step) apply(simp add: Let_def) -- "nice use of simp to instantiate"
   apply(drule_tac x="Suc na" in spec, drule_tac x="list @ [(0, finst f a), (Suc a, Exi f)]" in spec) apply(erule impE, assumption)
   apply(drule_tac x="Suc na" in spec, drule_tac x="list @ [(0, finst f a), (Suc a, Exi f)]" in spec) apply(erule impE) apply(rule) apply(arith) apply(assumption)
   apply(subgoal_tac "Svalid (list_sequent (list@[(0,finst f a), (Suc a, Exi f)]))")
    apply(simp add: list_sequent_def)
    apply(frule_tac sound_FEx) apply(simp) apply(simp)
   
  -- "now for other cases"
      -- "case empty list"
  apply(case_tac t) apply(simp)
   apply(frule_tac step) apply(simp) apply(simp) apply(metis add_Suc_shift add_right_cancel diff_add)
   
  apply(simp add: Svalid_def) apply(rule,rule) apply(rename_tac gs g) apply(rule) apply(rule) apply(simp add: SEval_def2)
  -- "na t in deriv, so too is subs"
   -- "if not a satax, then subs holds... "
  apply(case_tac a)
  apply(case_tac b)
       apply(simp del: semantics.simps) apply(frule_tac patom) apply(assumption)
       apply(rename_tac nat lista)
       apply(frule_tac x="Suc na" in spec, drule_tac x="list @ [(0, Pos nat lista)]" in spec)
       apply(erule impE) apply(arith)
       apply(drule_tac x=gs in spec, drule_tac x=g in spec, drule_tac x=e in spec) apply(erule impE) apply(simp add: is_model_environment_def)
       apply(elim exE conjE) apply(rule_tac x=f in exI) apply(simp add: list_sequent_def) -- "weirdly, simp succeeds, force and blast fail"
     apply(simp del: semantics.simps) apply(frule_tac fconj1) apply(assumption) apply(frule_tac fconj2) apply(assumption) 
     apply(rename_tac form1 form2)
     apply(frule_tac x="Suc na" in spec, drule_tac x="list @ [(0, form1)]" in spec)
     apply(erule impE) apply(arith)
     apply(drule_tac x=gs in spec, drule_tac x=g in spec, drule_tac x=e in spec) apply(erule impE, simp) apply(elim exE conjE)
     apply(drule_tac x="Suc na" in spec, drule_tac x="list @ [(0, form2)]" in spec)
     apply(erule impE) apply(arith)
     apply(drule_tac x=gs in spec, drule_tac x=g in spec, drule_tac x=e in spec) apply(erule impE, simp) apply(elim exE conjE)
     apply(simp only: list_sequent_def) 
     apply(simp)
     apply(elim disjE) 
        apply(simp) apply(rule_tac x="Con form1 form2" in exI) apply(simp)
       apply(simp) apply(rule_tac x="fa" in exI) apply(simp)
      apply(simp) apply(rule_tac x="f" in exI) apply(simp)
     apply(rule_tac x="f" in exI, simp)
   apply(force)
      apply(simp del: semantics.simps) apply(frule_tac natom) apply(assumption)
      apply(rename_tac nat lista)
      apply(frule_tac x="Suc na" in spec, drule_tac x="list @ [(0, Neg nat lista)]" in spec)
      apply(erule impE) apply(arith)
      apply(drule_tac x=gs in spec, drule_tac x=g in spec, drule_tac x=e in spec) apply(erule impE, simp)
      apply(elim exE conjE) apply(rule_tac x=f in exI) apply(simp add: list_sequent_def)
    apply(simp del: semantics.simps) apply(frule_tac fdisj) apply(assumption)
    apply(rename_tac form1 form2)
    apply(frule_tac x="Suc na" in spec, drule_tac x="list @ [(0, form1),(0,form2)]" in spec)
    apply(erule impE) apply(simp)
    apply(drule_tac x=gs in spec, drule_tac x=g in spec, drule_tac x=e in spec) apply(erule impE, simp) apply(elim exE conjE)
    apply(simp add: list_sequent_def)
    apply(elim disjE)
      apply(simp) apply(rule_tac x="Dis form1 form2" in exI) apply(simp)
     apply(simp) apply(rule_tac x="Dis form1 form2" in exI) apply(simp)
    apply(rule_tac x="f" in exI) apply(simp)
      -- "all case"
  apply(force)
  done

lemma xxx[simp]: "list_sequent (make_sequent s) = s"
  by (induct s) (simp_all add: list_sequent_def make_sequent_def)

lemma soundness: "finite (deriv (make_sequent s)) \<Longrightarrow> Svalid s"
  apply(subgoal_tac "init (make_sequent s)") 
   prefer 2 apply(simp add: init_def make_sequent_def)
  apply(subgoal_tac "finite (fst ` (deriv (make_sequent s)))") prefer 2 apply(simp)
  apply(frule_tac max_exists) apply(erule impE) apply(simp) apply(subgoal_tac "(0,make_sequent s) \<in> deriv (make_sequent s)") apply(force) apply(simp)
  apply(elim exE conjE)
  apply(frule_tac soundness') apply(assumption) apply(assumption) apply(force) 
  apply(drule_tac x=0 in spec, drule_tac x="make_sequent s" in spec)
  apply(force )
  done

subsection "Contains, Considers"

definition contains :: "(nat \<Rightarrow> (nat \<times> sequent)) \<Rightarrow> nat \<Rightarrow> nat \<times> form \<Rightarrow> bool"
where
  "contains f n nf = (nf \<in> set (snd (f n)))"

definition considers :: "(nat \<Rightarrow> (nat \<times> sequent)) \<Rightarrow> nat \<Rightarrow> nat \<times> form \<Rightarrow> bool"
where
  "considers f n nf = (case snd (f n) of [] \<Rightarrow> False | (x#xs) \<Rightarrow> x = nf)"

lemma (in loc1) progress: "infinite (deriv s) \<Longrightarrow> snd (f n) = a#list \<longrightarrow> (\<exists>zs'. snd (f (Suc n)) = list@zs')"
  apply(subgoal_tac "(snd (f (Suc n))) : set (subs (snd (f n)))") defer apply(frule_tac is_path_f) apply(blast)
  apply(case_tac a)
  apply(case_tac b)
  apply(safe)
  apply(simp_all add: Let_def split: if_splits)
  apply(erule disjE)
  apply(simp_all)
  done

lemma (in loc1) contains_considers': "infinite (deriv s) \<Longrightarrow> \<forall>n y ys. snd (f n) = xs@y#ys \<longrightarrow> (\<exists>m zs'. snd (f (n+m)) = y#zs')"
  apply(induct_tac xs)
  apply(rule,rule,rule,rule) apply(rule_tac x=0 in exI) apply(rule_tac x=ys in exI) apply(force)

  apply(rule,rule,rule,rule) apply(simp) apply(frule_tac progress) apply(erule impE) apply(assumption)
  apply(erule exE) apply(simp) 

  apply(drule_tac x="Suc n" in spec)
  apply(case_tac y) apply(rename_tac u v)
  apply(drule_tac x="u" in spec)
  apply(drule_tac x="v" in spec)
  apply(erule impE) apply(force)
  
  apply(elim exE)
  apply(rule_tac x="Suc m" in exI)
  apply(force)
  done

lemma list_decomp[rule_format]: "v \<in> set p \<longrightarrow> (\<exists> xs ys. p = xs@(v#ys) \<and> v \<notin> set xs)"
  apply(induct p)
  apply(force)
  apply(case_tac "v=a")
   apply(force)
  apply(auto)
  apply(rule_tac x="a#xs" in exI)
  apply(auto)
  done

lemma (in loc1) contains_considers: "infinite (deriv s) \<Longrightarrow> contains f n y \<Longrightarrow> (\<exists>m. considers f (n+m) y)"
  apply(simp add: contains_def considers_def)
  apply(frule_tac list_decomp) apply(elim exE conjE)
  apply(frule_tac contains_considers'[rule_format]) apply(assumption) apply(elim exE)
  apply(rule_tac x=m in exI)
  apply(force)
  done

lemma (in loc1) contains_propagates_patoms[rule_format]: "infinite (deriv s) \<Longrightarrow> contains f n (0, Pos p l) \<longrightarrow> contains f (n+q) (0, Pos p l)"
  apply(induct_tac q) apply(simp)
  apply(rule)
  apply(erule impE) apply(assumption)
  apply(subgoal_tac "~is_axiom (list_sequent (snd (f (n+na))))") defer
   apply(subgoal_tac "infinite (deriv (snd (f (n+na))))") defer
    apply(force dest: is_path_f)
   defer
   apply(rule) apply(simp add: deriv_is_axiom)
  apply(simp add: contains_def)
  apply(drule_tac p="snd (f (n + na))" in list_decomp) 
  apply(elim exE conjE)
  apply(case_tac xs)
   apply(simp)
   apply(subgoal_tac "(snd (f (Suc (n + na)))) : set (subs (snd (f (n + na))))")
    apply(simp add: Let_def split: if_splits)
   apply(frule_tac is_path_f) apply(drule_tac x="n+na" in spec) apply(force)
  apply(drule_tac progress)
  apply(erule impE) apply(force)
  apply(force)
  done

lemma (in loc1) contains_propagates_natoms[rule_format]: "infinite (deriv s) \<Longrightarrow> contains f n (0, Neg p l) \<longrightarrow> contains f (n+q) (0, Neg p l)"
  apply(induct_tac q) apply(simp)
  apply(rule)
  apply(erule impE) apply(assumption)
  apply(subgoal_tac "~is_axiom (list_sequent (snd (f (n+na))))") defer
   apply(subgoal_tac "infinite (deriv (snd (f (n+na))))") defer
    apply(force dest: is_path_f)
   defer
   apply(rule) apply(simp add: deriv_is_axiom)
  apply(simp add: contains_def)
  apply(drule_tac p = "snd (f (n + na))" in list_decomp) 
  apply(elim exE conjE)
  apply(case_tac xs)
   apply(simp)
   apply(subgoal_tac "(snd (f (Suc (n + na)))) : set (subs (snd (f (n + na))))")
    apply(simp add: Let_def split: if_splits)
   apply(frule_tac is_path_f) apply(drule_tac x="n+na" in spec) apply(force)
  apply(drule_tac progress)
  apply(erule impE) apply(force)
  apply(force)
  done

lemma (in loc1) contains_propagates_fconj: "infinite (deriv s) \<Longrightarrow> contains f n (0, Con g h) \<Longrightarrow> (\<exists>y. contains f (n+y) (0,g) | contains f (n+y) (0,h))"
  apply(subgoal_tac "(\<exists>l. considers f (n+l) (0,Con g h))") defer apply(rule contains_considers) apply(assumption) apply(assumption)
  apply(erule exE)
  apply(rule_tac x="Suc l" in exI)
  apply(simp add: considers_def) apply(case_tac "snd (f (n + l))", simp)
  apply(simp)
  apply(subgoal_tac "(snd (f (Suc (n + l)))) : set (subs (snd (f (n + l))))")
   apply(simp add: contains_def Let_def) apply(force)
  apply(frule_tac is_path_f) apply(drule_tac x="n+l" in spec) apply(force)
  done

lemma (in loc1) contains_propagates_fdisj: "infinite (deriv s) \<Longrightarrow> contains f n (0, Dis g h) \<Longrightarrow> (\<exists>y. contains f (n+y) (0,g) & contains f (n+y) (0,h))"
  apply(subgoal_tac "(\<exists>l. considers f (n+l) (0,Dis g h))") defer apply(rule contains_considers) apply(assumption) apply(assumption)
  apply(erule exE)
  apply(rule_tac x="Suc l" in exI)
  apply(simp add: considers_def) apply(case_tac "snd (f (n + l))", simp)
  apply(simp)
  apply(subgoal_tac " (snd (f (Suc (n + l)))) : set (subs (snd (f (n + l))))")
   apply(simp add: contains_def Let_def) 
  apply(frule_tac is_path_f) apply(drule_tac x="n+l" in spec) apply(force)
  done

lemma (in loc1) contains_propagates_fall: "infinite (deriv s) \<Longrightarrow> contains f n (0, Uni g)
  \<Longrightarrow> (\<exists>y. contains f (Suc(n+y)) (0,finst g (newvar (fv_list (list_sequent (snd (f (n+y))))))))" -- "may need constraint on fv"
  apply(subgoal_tac "(\<exists>l. considers f (n+l) (0,Uni g))") defer apply(rule contains_considers) apply(assumption) apply(assumption)
  apply(erule exE)
  apply(rule_tac x="l" in exI)
  apply(simp add: considers_def) apply(case_tac "snd (f (n + l))", simp)
  apply(simp)
  apply(subgoal_tac "(snd (f (Suc (n + l)))) : set (subs (snd (f (n + l))))")
   apply(simp add: contains_def Let_def) 
  apply(frule_tac is_path_f) apply(drule_tac x="n+l" in spec) apply(force)
  done

lemma (in loc1) contains_propagates_fex: "infinite (deriv s) \<Longrightarrow> contains f n (m, Exi g) 
  \<Longrightarrow> (\<exists>y. (contains f (n+y) (0,finst g m)) & (contains f (n+y) (Suc m,Exi g)))"
  apply(subgoal_tac "(\<exists>l. considers f (n+l) (m,Exi g))") defer apply(rule contains_considers) apply(assumption) apply(assumption)
  apply(erule exE)
  apply(rule_tac x="Suc l" in exI)
  apply(simp add: considers_def) apply(case_tac "snd (f (n + l))", simp)
  apply(simp)
  apply(subgoal_tac " (snd (f (Suc (n + l)))) : set (subs (snd (f (n + l))))")
   apply(simp add: contains_def Let_def) 
  apply(frule_tac is_path_f) apply(drule_tac x="n+l" in spec) apply(force)
  done

  -- "also need that if contains one, then contained an original at beginning"
  -- "existentials: show that for exists formulae, if Suc m is marker, then there must have been m"
  -- "show this by showing that nodes are upwardly closed, i.e. if never contains (m,x), then never contains (Suc m, x), by induction on n"

lemma (in loc1) FEx_downward: "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> \<forall>m. (Suc m,Exi g) \<in> set (snd (f n)) \<longrightarrow> (\<exists>n'. (m, Exi g) \<in> set (snd (f n')))"
  apply(frule_tac is_path_f)
  apply(induct_tac n)
   apply(drule_tac x="0" in spec) apply(case_tac "f 0") apply(force simp: init_def) 
  apply(intro allI impI)
  apply(frule_tac x="Suc n" in spec, elim conjE) apply(drule_tac x="n" in spec, elim conjE)
  apply(thin_tac "(snd (f (Suc (Suc n)))) : set (subs (snd (f (Suc n))))")
  apply(case_tac "f n") apply(simp)
  apply(case_tac b) apply(simp)
  apply(case_tac aa) apply(case_tac ba)
       apply(simp add: Let_def split: if_splits)
     apply(force simp add: Let_def)
    apply(force simp add: Let_def)
      apply(simp add: Let_def split: if_splits)
   apply(force simp add: Let_def)
  apply(rename_tac form)
  apply(case_tac "(ab, Exi form) = (m, Exi g)")
   apply(rule_tac x=n in exI) apply(force)
  apply(auto simp add: Let_def)
  done
   
lemma (in loc1) FEx0: "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> \<forall>n. contains f n (m,Exi g) \<longrightarrow> (\<exists>n'. contains f n' (0, Exi g))"
  apply(simp add: contains_def)
  apply(induct_tac m)
   apply(force)
  apply(intro allI impI) apply(erule exE) 
  apply(drule_tac FEx_downward[rule_format]) apply(assumption) apply(force)
  apply(elim exE conjE)
  apply(force)
  done
     
lemma (in loc1) FEx_upward': "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> \<forall>n. contains f n (0, Exi g) \<longrightarrow> (\<exists>n'. contains f n' (m, Exi g))"
  apply(intro allI impI)
  apply(induct_tac m) apply(force)
  apply(erule exE)
  apply(frule_tac n=n' in contains_considers) apply(assumption) 
  apply(erule exE)
  apply(rule_tac x="Suc(n'+m)" in exI)
  apply(frule_tac is_path_f) 
  apply(simp add: considers_def) apply(case_tac "snd (f (n'+m))") apply(force)
  apply(simp)
  apply(drule_tac x="n'+m" in spec)
  apply(force simp add: contains_def considers_def Let_def)
  done
  -- "FIXME contains and considers aren't buying us much"

lemma (in loc1) FEx_upward: "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> contains f n (m, Exi g) \<Longrightarrow> (\<forall>m'. \<exists>n'. contains f n' (0, finst g m'))"
  apply(intro allI impI)
  apply(subgoal_tac "\<exists>n'. contains f n' (m', Exi g)") defer
  apply(frule_tac m = m and g = g in FEx0) apply(assumption)
  apply(drule_tac x=n in spec)
  apply(simp)
  apply(elim exE)
  apply(frule_tac g=g and m=m' in FEx_upward') apply(assumption)
  apply (blast dest: contains_propagates_fex intro: elim:)+
  done

subsection "Models 2"

abbreviation ntou :: "nat \<Rightarrow> proxy" where "ntou == id"

abbreviation uton :: "proxy \<Rightarrow> nat" where "uton == id"

subsection "Falsifying Model From Failing Path"

definition model :: "sequent \<Rightarrow> model" where
  "model s = (range ntou, % p ms. (let f = failing_path (deriv s) in
    (\<forall>n m. ~ contains f n (m,Pos p (map uton ms)))))"

locale loc2 = loc1 +
  fixes mo
  assumes mo: "mo = model s"

lemma is_env_model_ntou: "is_model_environment (model s) ntou"
  by (simp add: is_model_environment_def model_def)

lemma (in loc1) [simp]: "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> (contains f n (m,A)) \<Longrightarrow> ~ is_FEx A \<Longrightarrow> m = 0"
  apply(frule_tac n=n in index0) 
  apply(frule_tac is_path_f) apply(drule_tac x=n in spec) apply(case_tac "f n")
  apply(simp)
  apply(simp add: contains_def)
  apply(force)
  done

lemma size_subst[simp]: "\<forall>m. size (subst m f) = size f"
  by (induct f) simp_all

lemma size_finst[simp]: "size (finst f m) = size f"
  by (simp add: finst_def)

lemma (in loc2) model': "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> \<forall>A. size A = h \<longrightarrow> (\<forall>m n. contains f n (m,A) \<longrightarrow> ~ (semantics mo ntou A))"

  apply(rule_tac nat_less_induct) apply(rule, rule) apply(case_tac A) 
       apply(rule,rule,rule) apply(simp add: mo Let_def) apply(simp add: model_def Let_def) apply(simp only: f[symmetric]) apply(force)

     apply(intro impI allI)
     apply(subgoal_tac "m=0") prefer 2 apply(simp) apply(simp del: semantics.simps)
     apply(frule_tac contains_propagates_fconj) apply(assumption)
     apply(rename_tac form1 form2 m na)
     apply(frule_tac x="size form1" in spec) apply(erule impE) apply(force) apply(drule_tac x="form1" in spec) apply(drule_tac x="size form2" in spec) apply(erule impE) apply(force) apply(simp)
     apply(force)

   apply(intro impI allI)
   apply(subgoal_tac "m=0") prefer 2 apply(simp) apply(simp del: semantics.simps)
   apply(frule_tac contains_propagates_fall) apply(assumption)
   apply(erule exE) -- "all case"
   apply(rename_tac form m na y)
   apply(drule_tac x="size form" in spec) apply(erule impE, force) apply(drule_tac x="finst form (newvar (fv_list (list_sequent (snd (f (na + y))))))" in spec) apply(erule impE, force)
   apply(erule impE, force) apply(simp add: FEval_finst) apply(rule_tac x="ntou (newvar (fv_list (list_sequent (snd (f (na + y))))))" in bexI) apply(simp)
   using is_env_model_ntou[of s] apply(simp add: is_model_environment_def mo)

      apply(rule,rule,rule) apply(simp add: mo Let_def) apply(simp add: model_def Let_def) apply(simp only: f[symmetric]) apply(rule ccontr) apply(simp) apply(elim exE)
      apply(subgoal_tac "m = 0 & ma = 0") prefer 2 apply(simp)
      apply(simp)
      apply(rename_tac nat list m na nb ma)
      apply(subgoal_tac "? y. considers f (nb+na+y) (0, Pos nat list)") prefer 2 apply(rule contains_considers) apply(assumption) 
       apply(rule contains_propagates_patoms) apply(assumption) apply(assumption)
      apply(erule exE)
      apply(subgoal_tac "contains f (na+nb+y) (0, Neg nat list)")
       apply(subgoal_tac "nb+na=na+nb") 
        apply(simp) apply(subgoal_tac "is_axiom (list_sequent (snd (f (na+nb+y))))")
         apply(drule_tac is_axiom_finite_deriv) apply(force dest: is_path_f)
        apply(simp add: contains_def considers_def) apply(case_tac "snd (f (na + nb + y))") apply(simp) apply(simp add: list_sequent_def) apply(force)
       apply(force)
      apply(force intro: contains_propagates_natoms contains_propagates_patoms)
    apply(intro impI allI)
    apply(subgoal_tac "m=0") prefer 2 apply(simp) apply(simp del: semantics.simps)
    apply(frule_tac contains_propagates_fdisj) apply(assumption)
    apply(rename_tac form1 form2 m na)
    apply(frule_tac x="size form1" in spec) apply(erule impE) apply(force) apply(drule_tac x="form1" in spec) apply(drule_tac x="size form2" in spec) apply(erule impE) apply(force) apply(simp)
    apply(force)

  apply(intro impI allI) apply(simp del: semantics.simps)
  apply(frule_tac FEx_upward) apply(assumption) apply(assumption)
  apply(simp)
  apply(rule)
  apply(rename_tac form m na ma)
  apply(subgoal_tac "\<forall>m'. ~ semantics mo ntou (finst form m')") 
   prefer 2 apply(rule)
   apply(drule_tac x="size form" in spec) apply(erule impE, force) 
   apply(drule_tac x="finst form m'" in spec) apply(erule impE, force) apply(erule impE) apply(force) apply(simp add: id_def)
  apply(simp add: FEval_finst id_def)
  done
   
lemma (in loc2) model: "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> (\<forall>A m n. contains f n (m,A) \<longrightarrow> ~ (semantics mo ntou A))"
  apply(rule)
  apply(frule_tac model') apply(auto)
  done

subsection "Completeness"

lemma (in loc2) completeness': "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> \<forall>mA \<in> set s. ~ semantics mo ntou (snd mA)" -- "FIXME tidy deriv s so that s consists of formulae only?"
  apply(frule_tac model) apply(assumption)
  apply(rule)
  apply(case_tac mA)
  apply(drule_tac x="b" in spec) apply(drule_tac x="0" in spec) apply(drule_tac x=0 in spec) apply(erule impE)
   apply(simp add: contains_def) apply(frule_tac is_path_f_0) apply(simp) 
   apply(subgoal_tac "a=0") 
    prefer 2 apply(simp only: init_def, force)
  apply auto
  done -- "FIXME very ugly"

lemma completeness': "infinite (deriv s) \<Longrightarrow> init s \<Longrightarrow> \<forall>mA \<in> set s. ~ semantics (model s) ntou (snd mA)"
  by (rule loc2.completeness'[simplified loc2_def loc2_axioms_def loc1_def]) simp

lemma completeness'': "infinite (deriv (make_sequent s)) \<Longrightarrow> init (make_sequent s) \<Longrightarrow> \<forall>A. A \<in> set s \<longrightarrow> ~ semantics (model (make_sequent s)) ntou A"
  using completeness' make_sequent_def by force

lemma completeness: "infinite (deriv (make_sequent s)) \<Longrightarrow> ~ Svalid s"
  apply(subgoal_tac "init (make_sequent s)") 
   prefer 2 apply(simp add: init_def make_sequent_def)
  apply(frule_tac completeness'') apply(assumption)
  apply(simp add: Svalid_def)
  apply(simp add: SEval_def2)
  apply(rule_tac x="fst (model (make_sequent s))" in exI)
  apply(rule_tac x="snd (model (make_sequent s))" in exI)
  apply(rule_tac x="ntou" in exI)
  apply(simp add: model_def)
  apply(simp add: is_model_environment_def)
  done
-- "FIXME silly splitting of quantified pairs "

proposition "Svalid s = finite (deriv (make_sequent s))"
  using soundness completeness by blast

subsection "Algorithm"

primrec iter :: "('a \<Rightarrow> 'a) \<Rightarrow> 'a \<Rightarrow> nat \<Rightarrow> 'a"
where
  "iter g a 0 = a"
| "iter g a (Suc n) = g (iter g a n)"

lemma iter: "\<forall>a. (iter g (g a) n) = (g (iter g a n))"
  by (induct n) auto

lemma ex_iter: "(\<exists>n. R (iter g a n)) = (if R a then True else (\<exists>n. R (iter g (g a) n)))"
  by (metis iter.simps iter not0_implies_Suc)

definition f :: "sequent list \<Rightarrow> nat \<Rightarrow> sequent list"
where
  "f s n = iter (% x. flatten (map subs x)) s n"

lemma f_upwards: "f s n = [] \<Longrightarrow> f s (n+m) = []"
  by (induct m) (auto simp add: f_def)

lemma flatten_append: "flatten (xs@ys) = ((flatten xs) @ (flatten ys))"
  by (induct xs) auto

lemma set_flatten: "set (flatten xs) = Union (set ` set xs)"
  by (induct xs) auto

lemma f: "\<forall>x. ((n,x) \<in> deriv s) = (x \<in> set (f [s] n))"
  apply(induct n)
  apply(simp) apply(simp add: f_def)
  apply(rule)
  apply(rule)
   apply(drule_tac deriv_downwards)
   apply(elim exE conjE)
   apply(drule_tac x=y in spec)
   apply(simp)
   apply(drule_tac list_decomp) apply(elim exE conjE)
   apply(simp add: flatten_append f_def Let_def)
  apply(simp add: f_def)
  apply(simp add: set_flatten)
  apply(erule bexE)
  apply(drule_tac x=a in spec)
  apply(rule step) apply(auto)
  done

lemma deriv_f: "deriv s = UNION UNIV (% x. set (map (% y. (x,y)) (f [s] x)))"
  by (force simp add: f)  

lemma finite_deriv: "finite (deriv s) = (\<exists>m. f [s] m = [])"
  apply(rule)
   apply(subgoal_tac "finite (fst ` (deriv s))") prefer 2 apply(simp)
   apply(frule_tac max_exists) apply(erule impE) apply(simp) apply(subgoal_tac "(0,s) \<in> deriv s") apply(force) apply(simp)
   apply(elim exE conjE)
   apply(rule_tac x="Suc x" in exI)
   apply(simp)
   apply(rule ccontr) apply(case_tac "f [s] (Suc x)") apply(simp) 
   apply(subgoal_tac "(Suc x, a) \<in> deriv s") apply(force)
   apply(simp add: f)
  apply(erule exE)
  apply(subgoal_tac "\<forall>y. f [s] (m+y) = []") 
   prefer 2 apply(rule) apply(rule f_upwards) apply(assumption)
  apply(simp add: deriv_f)
  apply(subgoal_tac "(UNIV::nat set) = {y. y < m} Un {y. m \<le> y}")
   prefer 2 apply force
  apply(erule_tac t="UNIV::nat set" in ssubst) 
  apply(simp)
  apply(subgoal_tac "(UN x:Collect (op \<le> m). Pair x ` set (f [s] x)) =  (UN x:Collect (op \<le> m). {})") apply(simp only:) apply(force)
  apply(rule SUP_cong) apply(force) apply(drule_tac x="x-m" in spec) apply(force)
  done

definition prove' :: "sequent list \<Rightarrow> bool" where
  "prove' s = (\<exists>m. iter (% x. flatten (map subs x)) s m = [])"

lemma prove': "prove' l = (if l = [] then True else prove' ((% x. flatten (map subs x)) l))"
  unfolding prove'_def by (rule ex_iter) 

abbreviation prove :: "sequent \<Rightarrow> bool" where "prove s \<equiv> prove' [s]"

corollary finite_deriv_prove: "finite (deriv s) = prove s"
  using finite_deriv prove'_def f_def by simp

subsection "Computation"

  -- "a sample formula to prove"
lemma "(\<exists>x. A x | B x) \<longrightarrow> ( (\<exists>x. B x) | (\<exists>x. A x))" by iprover

  -- "convert to our form"
lemma "((\<exists>x. A x | B x) \<longrightarrow> ( (\<exists>x. B x) | (\<exists>x. A x)))
  = ( (\<forall>x. ~ A x & ~ B x) | ( (\<exists>x. B x) | (\<exists>x. A x)))" by fast

definition my_f :: "form" where
  "my_f = Dis
  (Uni (Con (Neg ''A'' [0]) (Neg ''B'' [0])))
  (Dis (Exi (Pos ''B'' [0])) (Exi (Pos ''A'' [0])))"

  -- "we compute by rewriting"

lemma membership_simps:
  "x \<in> set [] \<longleftrightarrow> False"
  "x \<in> set (y # ys) \<longleftrightarrow> x = y \<or> x \<in> set ys"
  by simp_all

lemmas ss = list.inject if_True if_False flatten.simps list.map
  fv_list_def filter.simps is_axiom.simps fst_conv snd_conv
  form.simps inc_def finst_def make_sequent_def list_sequent_def
  Let_def newvar_def subs.simps split_beta append_Nil append_Cons
  subst.simps nat.simps fv.simps maxvar.simps preSuc.simps simp_thms
  membership_simps

lemmas prove'_Nil = prove' [of "[]", simplified]
lemmas prove'_Cons = prove' [of "x#l", simplified] for x l

lemma search: "finite (deriv [(0,my_f)])"
  by (simp only: my_f_def finite_deriv_prove) (simp only: prove'_Nil prove'_Cons ss mm)

abbreviation Sprove :: "form list \<Rightarrow> bool" where "Sprove \<equiv> prove o make_sequent"

abbreviation check :: "form \<Rightarrow> bool" where "check formula \<equiv> Sprove [formula]"

abbreviation valid :: "form \<Rightarrow> bool" where "valid formula \<equiv> Svalid [formula]"

theorem "check = valid" using soundness completeness finite_deriv_prove by auto

ML \<open>

fun max x y = if x > y then x else y;

fun flatten [] = []
  | flatten (a::list) = a @ (flatten list);

type predicate = int;

type nat = int;

datatype form = 
    Pos of predicate * (nat list)
  | Neg of predicate * (nat list)
  | Con of form * form
  | Dis of form * form
  | Uni of form
  | Exi of form;

fun preSuc [] = []
  | preSuc (a::list) = if a = 0 then preSuc list else (a-1)::(preSuc list);

fun fv (Pos (_,l)) = l
  | fv (Neg (_,l)) = l
  | fv (Con (f,g)) = (fv f) @ (fv g)
  | fv (Dis (f,g)) = (fv f) @ (fv g)
  | fv (Uni f) = preSuc (fv f)
  | fv (Exi f) = preSuc (fv f);

fun subst r (Pos (p,l)) = Pos (p,map r l)
  | subst r (Neg (p,l)) = Neg (p,map r l)
  | subst r (Con (f,g)) = Con (subst r f,subst r g)
  | subst r (Dis (f,g)) = Dis (subst r f,subst r g)
  | subst r (Uni f) = Uni (subst (fn 0 => 0 | v => (r (v-1))+1) f)
  | subst r (Exi f) = Exi  (subst (fn 0 => 0 | v => (r (v-1))+1) f);

fun finst body w = subst (fn 0 => w | v => v-1) body;

fun list_sequent ns = map (fn (_,y) => y) ns;

fun make_sequent s = map (fn y => (0,y)) s;

fun fv_list s = flatten (map fv s);

fun maxvar [] = 0
  | maxvar (a::list) = max a (maxvar list);

fun newvar l = if l = [] then 0 else (maxvar l)+1;

fun test [] _ = false
  | test ((_,y)::list) z = if y = z then true else test list z;

fun subs [] = [[]]
  | subs (x::xs) = let val (n,f') = x in case f' of
      Pos (p,l) => if test xs (Neg (p,l)) then [] else [xs @ [(0,Pos (p,l))]]
    | Neg (p,l) => if test xs (Pos (p,l)) then [] else [xs @ [(0,Neg (p,l))]]
    | Con (f,g) => [xs @ [(0,f)],xs @ [(0,g)]]
    | Dis (f,g) => [xs @ [(0,f),(0,g)]]
    | Uni f => [xs @ [(0,finst f (newvar (fv_list (list_sequent (x::xs)))))]]
    | Exi f => [xs @ [(0,finst f n),(n+1,f')]]
  end;

fun step s = flatten (map subs s);

fun prove' s = if s = [] then true else prove' (step s);

fun prove s = prove' [s];

fun check f = (prove o make_sequent) [f];

val my_f = Dis (
  (Uni (Con ((Neg (0,[0])), (Neg (1,[0])))),
  (Dis ((Exi ((Pos (1,[0])))), (Exi (Pos (0,[0])))))));

check my_f;

\<close>

end
