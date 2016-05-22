#include <assert.h>
#include <limits.h> /* for CHAR_BIT */
#include <stdlib.h>
#include <stdio.h> /* for printing error messages */
#include <string.h>
#include "malloca.h"

#include "linear_sorted_search.c"

static inline
int linear_sorted_search_K_V(const K *key,
                             const K *ptr,
                             size_t count,
                             size_t *pos_out)
{
    return linear_sorted_search(key,
                                ptr,
                                count,
                                sizeof(*ptr),
                                &generic_compare_K,
                                NULL,
                                pos_out);
}

#include "binary_search.c"

static inline
int binary_sorted_search_K_V(const K *key,
                             const K *ptr,
                             size_t count,
                             size_t *pos_out)
{
    return binary_search(key,
                         ptr,
                         count,
                         sizeof(*ptr),
                         &generic_compare_K,
                         NULL,
                         pos_out);
}

typedef unsigned short child_index_type;
typedef unsigned char height_type;

typedef struct {
    /* the number of valid keys (or number of valid values),
       ranging from 0 to 2 * B - 1 */
    child_index_type _len;
    /* an array of keys, with [0, _len) valid */
    K _keys[2 * B - 1];
#ifdef V
    /* an array of values, with [0, _len) valid */
    V _values[2 * B - 1];
#endif
} leaf_node;

/** A simple container used for readability purposes */
struct elem_ref {
    K *key;
    V *value;
    leaf_node **child; /* right child */
};

static inline
child_index_type *leaf_len(leaf_node *m)
{
    return &m->_len;
}

static inline
K *leaf_keys(leaf_node *m)
{
    return m->_keys;
}

static inline
V *leaf_values(leaf_node *m)
{
    return m->_values;
}

typedef struct branch_node_ {
    /* we use `leaf_node` as a "base type" */
    leaf_node _data;
    /* child nodes, with [0, _data._len] valid */
    leaf_node *_children[2 * B];
} branch_node;

static inline
leaf_node **branch_children(branch_node *m)
{
    return m->_children;
}

static inline
leaf_node *branch_as_leaf(branch_node *m)
{
    return &m->_data;
}

/** It must actually be a branch, or this will cause UB. */
static inline
branch_node *unsafe_leaf_as_branch(leaf_node *m)
{
    return (branch_node *)m;
}

/** It must actually be a branch, or this will cause UB. */
static inline
leaf_node **unsafe_leaf_children(leaf_node *m)
{
    return branch_children(unsafe_leaf_as_branch(m));
}

/** May return NULL if it's not a branch. */
static inline
branch_node *try_leaf_as_branch(int is_branch, leaf_node *m)
{
    if (!is_branch) {
        return NULL;
    }
    return unsafe_leaf_as_branch(m);
}

static inline
struct elem_ref node_elems(int is_branch, leaf_node *m)
{
    struct elem_ref r = {
        leaf_keys(m),
        leaf_values(m),
        /* we always manipulate the key+value with its RIGHT child */
        is_branch ? unsafe_leaf_children(m) + 1 : NULL
    };
    return r;
}

typedef struct {
    leaf_node *_root;
    child_index_type _len;
    height_type _height;
} btree;

#ifndef MAX_HEIGHT
/* Obtain a lower bound on the logarithm of a number */
#define MINLOG2(x)                              \
    ((x) >= 256 ? 8 :                           \
     (x) >= 128 ? 7 :                           \
     (x) >= 64 ? 6 :                            \
     (x) >= 32 ? 5 :                            \
     (x) >= 16 ? 4 :                            \
     (x) >= 8 ? 3 :                             \
     (x) >= 4 ? 2 :                             \
     (x) >= 2 ? 1 :                             \
     0)
/* log2(UINTPTR_MAX / sizeof(leaf_node)) / log2(B) + 1 */
#define MAX_HEIGHT                                                      \
    ((CHAR_BIT * sizeof(void *) - MINLOG2(sizeof(leaf_node))) / MINLOG2(B) + 1)
#endif

#include "compat/static_assert_begin.h"
static_assert((height_type)MAX_HEIGHT == MAX_HEIGHT, "height is too big");
static_assert((child_index_type)B == B, "B is too big");
#include "compat/static_assert_end.h"

typedef struct {
    leaf_node *_nodestack[MAX_HEIGHT];
    child_index_type _istack[MAX_HEIGHT];
    height_type _depth;
} btree_cursor;

void init_btree(btree *m)
{
    m->_len = 0;
    m->_height = 0;
    m->_root = NULL;
}

static
void free_node(height_type height, leaf_node *m)
{
    branch_node *mb = try_leaf_as_branch(height, m);
    if (mb) {
        for (child_index_type i = 0; i < *leaf_len(m) + 1; ++i) {
            free_node(height - 1, branch_children(mb)[i]);
        }
    }
    // printf("free(%p)\n", (void *)m);
    free(m);
}

void reset_btree(btree *m)
{
    free_node(m->_height - 1, m->_root);
    init_btree(m);
}

child_index_type btree_len(const btree *m)
{
    return m->_len;
}

static inline
leaf_node *lookup_iter(child_index_type *i_out,
                       leaf_node *node,
                       height_type *h,
                       height_type height,
                       const K *key)
{
    size_t i;
    int r;
    assert(height);
    r = LOOKUP_METHOD(key, leaf_keys(node), *leaf_len(node), &i);
    *i_out = (child_index_type)i;
    if (r || ++*h >= height) {
        return NULL;
    }
    return branch_children(unsafe_leaf_as_branch(node))[*i_out];
}

/** Return the node and the position within that node. */
height_type raw_lookup_node(leaf_node **nodestack,
                            child_index_type *istack,
                            height_type height,
                            leaf_node *node,
                            const K *key)
{
    height_type h = 0;
    assert(height);
    nodestack[0] = node;
    while ((node = lookup_iter(&istack[h], nodestack[h], &h, height, key))) {
        nodestack[h] = node;
    }
    return h;
}

void btree_lookup(btree_cursor *cur, btree *m, const K *key)
{
    assert(m->_height <= MAX_HEIGHT);
    if (!m->_height) {
        cur->_depth = 0;
        return;
    }
    cur->_depth = raw_lookup_node(cur->_nodestack,
                                  cur->_istack,
                                  m->_height,
                                  m->_root,
                                  key);
}

/** Return the node and the position within that node. */
leaf_node *find_node(height_type height,
                     leaf_node *node,
                     const K *key,
                     child_index_type *index)
{
    child_index_type i;
    height_type h = 0;
    leaf_node *newnode;
    while ((newnode = lookup_iter(&i, node, &h, height, key))) {
        node = newnode;
    }
    if (h == height) {
        return NULL;
    }
    *index = i;
    return node;
}

/** Return the node and the position within that node. */
leaf_node *btree_get_node(btree *m, const K *key, child_index_type *index)
{
    if (!m->_root) {
        assert(m->_height == 0);
        assert(m->_len == 0);
        return NULL;
    }
    return find_node(m->_height, m->_root, key, index);
}

#ifdef V

V *btree_get(btree *m, const K *k)
{
    child_index_type i;
    leaf_node *n = btree_get_node(m, k, &i);
    if (!n) {
        return NULL;
    }
    return &leaf_values(n)[i];
}

const V *btree_get_const(const btree *m, const K *k)
{
    return btree_get((btree *)m, k);
}

#endif

int btree_in(const btree *m, const K *k)
{
    child_index_type i;
    return !!btree_get_node((btree *)m, k, &i);
}

static inline
void copy_elems(struct elem_ref dst,
                struct elem_ref src,
                size_t count)
{
    /* use memmove due to potential for overlap; it's not always needed, but
       better safe than sorry and the performance impact here is minimal */
    memmove(dst.key, src.key, count * sizeof(*src.key));
    memmove(dst.value, src.value, count * sizeof(*src.value));
    assert(!!dst.child == !!src.child);
    if (src.child) {
        memmove(dst.child, src.child, count * sizeof(*src.child));
    }
}

static inline
struct elem_ref offset_elem(struct elem_ref dst, size_t count)
{
    struct elem_ref r = {
        dst.key + count,
        dst.value + count,
        dst.child ? dst.child + count : NULL
    };
    return r;
}

static inline
int insert_node_here(int is_branch,
                     leaf_node *node,
                     child_index_type i,
                     struct elem_ref elem,
                     struct elem_ref elem_out)
{
    child_index_type len = *leaf_len(node);

    /* case A: enough room to do a simple insert */
    struct elem_ref elems = node_elems(is_branch, node);
    if (len < 2 * B - 1) {
        copy_elems(offset_elem(elems, i + 1), offset_elem(elems, i), len - i);
        copy_elems(offset_elem(elems, i), elem, 1);
        ++*leaf_len(node);
        return 0;
    }

    /* case B: not enough room; need to split node */
    assert(len == 2 * B - 1);
    leaf_node *newnode = (leaf_node *)malloc(
        is_branch ?
        sizeof(branch_node) :
        sizeof(leaf_node));
    if (!newnode) {
        /* FIXME: we should return 1 instead of failing, but we'd need to
           rollback the incomplete insert, which is tricky :c */
        fprintf(stderr, "%s:%lu: Out of memory\n",
                __FILE__, (unsigned long)__LINE__);
        fflush(stderr);
        abort();
    }
    struct elem_ref newelems = node_elems(is_branch, newnode);
    size_t s = i > B ? i : B;
    copy_elems(offset_elem(newelems, s - B), offset_elem(elems, s),
               B * 2 - 1 - s);
    if (i == B) {
        if (is_branch) {
            unsafe_leaf_children(newnode)[0] = *elem.child;
        }
        *elem_out.key = *elem.key;
        *elem_out.value = *elem.value;
    } else {
        child_index_type mid = i < B ? B - 1 : B;
        K midkey = leaf_keys(node)[mid];;
        V midvalue = leaf_values(node)[mid];
        if (is_branch) {
            unsafe_leaf_children(newnode)[0] =
                unsafe_leaf_children(node)[mid + 1];
        }
        if (i < B) {
            copy_elems(offset_elem(elems, i + 1), offset_elem(elems, i),
                       B - 1 - i);
            copy_elems(offset_elem(elems, i), elem, 1);
        } else {
            copy_elems(newelems, offset_elem(elems, B + 1), i - B - 1);
            copy_elems(offset_elem(newelems, i - B - 1), elem, 1);
        }
        *elem_out.key = midkey;
        *elem_out.value = midvalue;
    }
    *leaf_len(node) = B;
    *leaf_len(newnode) = B - 1;
    *elem_out.child = newnode;
    return -2;
}

static inline
int insert_node(height_type height,
                leaf_node *node,
                const K *key,
                const V *value,
                struct elem_ref newelem)
{
    int r;
    height_type h = 0;
    MALLOCA(child_index_type, istack, height);
    MALLOCA(leaf_node *, nodestack, height);
    h = raw_lookup_node(nodestack, istack, height, node, key);
    if (h != height) {
        leaf_values(nodestack[h])[istack[h]] = *value;
        r = -1;
    } else {
        /* the rest of it does not depend on the comparison operation, only on
           the layout of the structure */
        h = height - 1;
        struct elem_ref elem = {(K *)key, (V *)value, NULL};
        r = insert_node_here(0, nodestack[h], istack[h], elem, newelem);
        while (h-- && r < -1) {
            r = insert_node_here(1, nodestack[h], istack[h], newelem, newelem);
        }
    }
    FREEA(nodestack);
    FREEA(istack);
    return r;
}

int btree_insert(btree *m, const K *key, const V *value)
{
    if (!m->_root) {
        assert(m->_len == 0);
        assert(m->_height == 0);
        m->_root = (leaf_node *)malloc(sizeof(*m->_root));
        if (!m->_root) {
            return 1;
        }
        ++m->_len; // uhhh wait what if the insert was a dupe
        m->_height = 1;
        *leaf_len(m->_root) = 1;
        leaf_keys(m->_root)[0] = *key;
        leaf_values(m->_root)[0] = *value;
        return 0;
    }
    K newkey;
    V newvalue;
    leaf_node *newchild;
    struct elem_ref newelem = {&newkey, &newvalue, &newchild};
    int r = insert_node(m->_height,
                        m->_root,
                        key,
                        value,
                        newelem);
    if (r == 0) {                       /* added a new element */
        ++m->_len;
    } else if (r == -1) {               /* updated an existing element */
        r = 0;
    }
    if (r >= 0) {
        return r;
    }
    branch_node *newroot = (branch_node *)malloc(sizeof(*newroot));
    if (!newroot) {
        /* FIXME: we should return 1 instead of failing, but we'd need
           to rollback the incomplete insert, which is tricky :c */
        fprintf(stderr, "%s:%lu: Out of memory\n",
                __FILE__, (unsigned long)__LINE__);
        fflush(stderr);
        abort();
    }
    ++m->_height;
    *leaf_len(branch_as_leaf(newroot)) = 1;
    leaf_keys(branch_as_leaf(newroot))[0] = newkey;
    leaf_values(branch_as_leaf(newroot))[0] = newvalue;
    branch_children(newroot)[0] = m->_root;
    // printf("btree_insert: newchild=%p\n", (void *)newchild);
    branch_children(newroot)[1] = newchild;
    m->_root = branch_as_leaf(newroot);
    return 0;
}

void delete_at_cursor(btree *m, btree_cursor *cur)
{
    height_type depth = cur->_depth;
    height_type height = m->_height;
    /* disallow iterators that don't point to an exact element */
    assert(depth < height);

    /* if node is not leaf, swap with the nearest leaf to the left */
    if (depth < height - 1) {
        height_type h = depth;
        leaf_node *uppernode = cur->_nodestack[depth];
        child_index_type upperi = cur->_istack[depth];
        K *key = &leaf_keys(uppernode)[upperi];
        leaf_node *node = uppernode;
        size_t i = upperi;
        ++h;
        do {
            node = branch_children(unsafe_leaf_as_branch(node))[i];
            cur->_nodestack[h] = node;
            i = *leaf_len(node);
            cur->_istack[h] = i;
            ++h;
        } while (h < height);
        --cur->_istack[height - 1];
        leaf_node *lowernode = cur->_nodestack[height - 1];
        child_index_type loweri = cur->_istack[height - 1];
        *key = leaf_keys(lowernode)[loweri];
        leaf_values(uppernode)[upperi] = leaf_values(lowernode)[loweri];
    }
// TODO
}

#define INDENT 2

static
void dump_node(size_t indent, height_type height, leaf_node *m)
{
    // printf("dump_node(%p)\n", (void *)m);
    branch_node *mb = try_leaf_as_branch(height, m);
    child_index_type i;
    for (i = 0; i < *leaf_len(m); ++i) {
        if (mb) {
            dump_node(indent + INDENT, height - 1, branch_children(mb)[i]);
        }
        for (size_t j = 0; j < indent; ++j) {
            printf(" ");
        }
        if (height)
            printf("\033[37m%03zu\033[32m,%03.0f\033[0m\n",
                   leaf_keys(m)[i], leaf_values(m)[i]);
        else
            printf("\033[37m%03zu\033[33m,%03.0f\033[0m\n",
                   leaf_keys(m)[i], leaf_values(m)[i]);
    }
    if (mb) {
        dump_node(indent + INDENT, height - 1, branch_children(mb)[i]);
    }
}

/** For debugging purposes. */
void dump_btree(btree *m)
{
    if (!m->_root) {
        printf("(empty)\n");
    } else {
        dump_node(0, m->_height - 1, m->_root);
    }
    printf("----------------------------------------\n");
}
