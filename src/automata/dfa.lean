import data.set.basic
import data.fintype.basic
import tactic

namespace dfa
open set list

variables {S Q : Type} [fintype S] [fintype Q] [decidable_eq Q]

structure DFA (S : Type) (Q : Type) [fintype S] [fintype Q] [decidable_eq Q] :=
    (start : Q) -- starting state
    (term : set Q) -- terminal states
    (next : Q → S → Q) -- transitions

inductive go (dfa : DFA S Q) : Q → list S → Q → Prop
| finish : Π {q : Q}, go q [] q
| step   : Π {head : S} {tail : list S} {q f : Q},
    go (dfa.next q head) tail f → go q (head::tail) f

@[simp] def dfa_accepts_word (dfa : DFA S Q) (w : list S) : Prop := 
    ∃ {t}, go dfa dfa.start w t ∧ t ∈ dfa.term

@[simp] def lang_of_dfa (dfa : DFA S Q) := {w | dfa_accepts_word dfa w}

def dfa_lang (lang : set (list S)) := 
    ∃ (Q : Type) [fintype Q] [decidable_eq Q], by exactI ∃ {dfa : DFA S Q}, lang = lang_of_dfa dfa 

@[simp] lemma dfa_go_step_iff (dfa : DFA S Q) (q : Q) {head : S} {tail : list S} :
    go dfa q (head :: tail) = go dfa (dfa.next q head) tail :=
begin
    ext, split,
    { rintro ⟨_⟩, assumption },
    { exact go.step }, 
end

lemma dfa_go_exists_unique (dfa : DFA S Q) (a : Q) (l : list S):
    ∃! {b : Q}, go dfa a l b :=
begin
    induction l with head tail hyp generalizing a, {
        use [a, go.finish],
        rintro y ⟨_⟩,
        refl,
    }, {
        specialize @hyp (dfa.next a head),
        convert hyp,
        rwa dfa_go_step_iff,        
    }
end

lemma dfa_go_unique {dfa : DFA S Q} {l : list S} {a b c : Q} :
    go dfa a l b → go dfa a l c → b = c :=
begin
    rcases dfa_go_exists_unique dfa a l with ⟨d, dgo, h⟩,
    dsimp at *,
    intros bgo cgo,
    replace bgo := h b bgo,
    replace cgo := h c cgo,
    finish,     
end

lemma dfa_go_append {dfa : DFA S Q} {a b c : Q} {left right : list S}:
    go dfa a left b → go dfa b right c → go dfa a (left ++ right) c :=
begin
    induction left with head tail hyp generalizing a, {
        rintro ⟨_⟩ hbc,
        exact hbc,
    }, {
        rintro (⟨_⟩ | ⟨head, tail, _, _, hab⟩) hbc,
        specialize @hyp (dfa.next a head),
        exact go.step (hyp hab hbc),
    }
end

lemma eq_next_goes_to_iff 
    (d1 d2 : DFA S Q) (h : d1.next = d2.next) (w : list S) (q r : Q)
    : go d1 q w r ↔ go d2 q w r := 
begin
    induction w with head tail hyp generalizing q, {
        split;
        { intro h, cases h, exact go.finish }
    }, {
        specialize @hyp (d1.next q head),
        repeat {rw [dfa_go_step_iff] at *},
        rwa h at *,
    },
end

@[simp] lemma mem_lang_iff_dfa_accepts 
    {L : set (list S)} {dfa : DFA S Q} {w : list S} (autl : L = lang_of_dfa dfa) 
    : w ∈ L ↔ dfa_accepts_word dfa w := 
begin
    split; finish,
end

def compl_dfa (dfa : DFA S Q) : DFA S Q := {
    start := dfa.start,
    term := dfa.termᶜ,
    next := dfa.next,
}

lemma lang_of_compl_dfa_is_compl_of_lang (dfa : DFA S Q) : 
    (lang_of_dfa dfa)ᶜ = lang_of_dfa (compl_dfa dfa) :=
begin
    apply subset.antisymm, {
        rw [compl_subset_iff_union, eq_univ_iff_forall],
        intro x,
        rcases (dfa_go_exists_unique dfa dfa.start x) with ⟨t, tgo, tuniq⟩,
        by_cases tterm : t ∈ dfa.term, {
            left,
            use [t, tgo, tterm],
        }, {
            right,
            use t,
            rw eq_next_goes_to_iff (compl_dfa dfa) dfa rfl x (compl_dfa dfa).start,
            use tgo,
        }
    }, {
        rw [subset_compl_iff_disjoint, eq_empty_iff_forall_not_mem],
        rintro x ⟨⟨t, tgo, tterm⟩, ⟨r, rgo, rterm⟩⟩,
        rw eq_next_goes_to_iff (compl_dfa dfa) dfa rfl x (compl_dfa dfa).start t at tgo,
        have h : t = r := by apply dfa_go_unique tgo rgo,
        finish,
    }, 
end

theorem compl_is_dfa {L : set (list S)} : dfa_lang L → dfa_lang Lᶜ :=
begin
    rintro ⟨Q, fQ, dQ, dfa, rfl⟩,
    resetI,
    use [Q, fQ, dQ, compl_dfa dfa],
    rw lang_of_compl_dfa_is_compl_of_lang,
end

section inter_dfa

variables {Ql Qm : Type} [fintype Ql] [fintype Qm] [decidable_eq Ql] [decidable_eq Qm]

def inter_dfa (l : DFA S Ql) (m : DFA S Qm) : DFA S (Ql × Qm) := {
    start := (l.start, m.start),
    term := {p : (Ql × Qm) | p.1 ∈ l.term ∧ p.2 ∈ m.term},
    next := λ (st : Ql × Qm) (c : S), (l.next st.1 c, m.next st.2 c)
}

lemma inter_dfa_go (l : DFA S Ql) (m : DFA S Qm) {ql qm rl rm}
     : ∀ {w : list S}, (go l ql w rl ∧ go m qm w rm) ↔ go (inter_dfa l m) (ql, qm) w (rl, rm):=
begin
    intro w,
    induction w with head tail hyp generalizing ql qm, {
        split, 
        { rintro ⟨⟨_⟩, ⟨_⟩⟩, apply go.finish }, 
        { rintro ⟨_⟩, split; apply go.finish },
    }, {
        specialize @hyp (l.next ql head) (m.next qm head),
        repeat {rwa dfa_go_step_iff at *},
    },
end

theorem inter_is_dfa {L M : set (list S)} 
    (hl : dfa_lang L) (hm : dfa_lang M) : dfa_lang (L ∩ M) :=
begin
    rcases hl with ⟨Ql, fQl, dQl, dl, hl⟩,
    rcases hm with ⟨Qm, fQm, dQm, dm, hm⟩,
    letI := fQl,
    letI := fQm,
    existsi [Ql × Qm, _, _, inter_dfa dl dm],
    ext word, 
    split, {
        rintro ⟨xl, xm⟩,
        rw mem_lang_iff_dfa_accepts hl at xl,
        rw mem_lang_iff_dfa_accepts hm at xm,
        rcases xl with ⟨lt, lgo, lterm⟩,
        rcases xm with ⟨mt, mgo, mterm⟩,
        use [(lt, mt)],
        split,
        apply (inter_dfa_go dl dm).1,
        use [lgo, mgo],
        use [lterm, mterm],
    }, {
        rintro ⟨⟨lt, mt⟩, intergo, ⟨lterm, mterm⟩⟩,
        have intergo := (inter_dfa_go dl dm).2 intergo,
        dsimp only [mem_inter_eq],
        rw [mem_lang_iff_dfa_accepts hl, mem_lang_iff_dfa_accepts hm],
        use [lt, intergo.1, lterm],
        use [mt, intergo.2, mterm],
    },
end

theorem union_is_dfa {L M : set (list S)} 
    (hl : dfa_lang L) (hm : dfa_lang M) : dfa_lang (L ∪ M) :=
begin
    rw union_eq_compl_compl_inter_compl,
    apply compl_is_dfa,
    apply inter_is_dfa,
    exact compl_is_dfa hl,
    exact compl_is_dfa hm,
end

end inter_dfa
    
end dfa