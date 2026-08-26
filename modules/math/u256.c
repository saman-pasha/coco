#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
struct coco_engine_opaque; struct coco_machine_opaque; ;
#define coco_engine struct coco_engine_opaque 
#define coco_machine struct coco_machine_opaque 
#define u32 uint32_t 
#define i64 int64_t 
int coco_module_register (const char * name , int (*dispatch) (coco_engine * e , const char * nm , uint32_t arity , size_t g , int * found ), const char * prolog , int (*init) (coco_engine * e ));
size_t coco_m_arg (coco_engine * e , size_t g , uint32_t i );
coco_machine * coco_m_machine (coco_engine * e );
size_t coco_m_mark (coco_engine * e );
void coco_m_undo (coco_engine * e , size_t mark );
int coco_m_is_var (coco_engine * e , size_t t );
int coco_m_is_atom (coco_engine * e , size_t t );
const char * coco_m_atom (coco_engine * e , size_t t );
int coco_m_int (coco_engine * e , size_t t , int64_t * out );
int coco_m_float (coco_engine * e , size_t t , double * out );
int coco_m_text (coco_engine * e , size_t t , char * buf , size_t cap );
int coco_m_unify (coco_engine * e , size_t t , size_t u );
int coco_m_unify_atom (coco_engine * e , size_t t , const char * s );
int coco_m_unify_int (coco_engine * e , size_t t , int64_t v );
int coco_m_unify_float (coco_engine * e , size_t t , double v );
size_t coco_m_nil (coco_engine * e );
size_t coco_m_cons (coco_engine * e , size_t h , size_t t );
size_t coco_m_atom_list (coco_engine * e , char ** v , size_t n );
size_t coco_m_list (coco_engine * e , const size_t * items , size_t n );
int coco_m_list_length (coco_engine * e , size_t t , size_t * out );
int coco_m_list_array (coco_engine * e , size_t t , size_t ** out , size_t * n );
int coco_m_tensor_put (coco_engine * e , const char * name , int64_t seq , const double * v , uint32_t n );
int coco_m_tensor_row (coco_engine * e , const char * name , int64_t seq , double * out , uint32_t cap , uint32_t * n );
int coco_m_tensor_forget (coco_engine * e , const char * name );
int coco_m_type_error (coco_engine * e , const char * type , size_t culprit );
int coco_m_instantiation_error (coco_engine * e );
int coco_m_domain_error (coco_engine * e , const char * domain , size_t culprit );
int coco_m_existence_error (coco_engine * e , const char * kind , size_t what );
int coco_m_error (coco_engine * e , const char * what , const char * detail );
static void u_set0 (uint32_t * a ) {
  for (int i  = 0; (i  <  8 ); (++i )) {
      a [i ] = 0;
  }
}
static void u_set1 (uint32_t * a , uint32_t v ) {
  u_set0 (a );
  a [0] = v ;
}
static void u_cpy (uint32_t * d , const uint32_t * s ) {
  for (int i  = 0; (i  <  8 ); (++i )) {
      d [i ] = s [i ];
  }
}
static int u_zero_p (const uint32_t * a ) {
  for (int i  = 0; (i  <  8 ); (++i )) {
      if (a [i ] !=  0 )
        return 0;
  }
  return 1;
}
static int u_cmp (const uint32_t * a , const uint32_t * b ) {
  for (int i  = 7; (i  >=  0 ); (--i )) {
      if (a [i ] >  b [i ] )
        return 1;
      if (a [i ] <  b [i ] )
        return -1;
  }
  return 0;
}
static uint32_t u_add (uint32_t * r , const uint32_t * a , const uint32_t * b ) {
  { /* let168 */
    uint64_t c  = 0;
    // ----------
    for (int i  = 0; (i  <  8 ); (++i )) {
        c  = (c  +  (((uint64_t)a [i ]) +  ((uint64_t)b [i ]) ) );
        r [i ] = ((uint32_t)c );
        c  = (c  >>  32 );
    }
    return ((uint32_t)c );
  }
}
static uint32_t u_sub (uint32_t * r , const uint32_t * a , const uint32_t * b ) {
  { /* let174 */
    int64_t br  = 0;
    // ----------
    for (int i  = 0; (i  <  8 ); (++i )) {
        { /* let179 */
          int64_t d  = ((((int64_t)a [i ]) -  ((int64_t)b [i ]) ) -  br  );
          // ----------
          if (d  <  0 )
            { /* block183 */
              d  = (d  +  4294967296 );
              br  = 1;
            }
          else
            br  = 0;
          r [i ] = ((uint32_t)d );
        }
    }
    return ((uint32_t)br );
  }
}
static void u_mul512 (uint32_t * r , const uint32_t * a , const uint32_t * b ) {
  for (int i  = 0; (i  <  16 ); (++i )) {
      r [i ] = 0;
  }
  for (int i  = 0; (i  <  8 ); (++i )) {
      { /* let193 */
        uint64_t c  = 0;
        // ----------
        for (int j  = 0; (j  <  8 ); (++j )) {
            c  = ((c  +  ((uint64_t)r [(i  +  j  )]) ) +  (((uint64_t)a [i ]) *  ((uint64_t)b [j ]) ) );
            r [(i  +  j  )] = ((uint32_t)c );
            c  = (c  >>  32 );
        }
        { /* let198 */
          int k  = (i  +  8 );
          // ----------
          while (((c  !=  0 ) &&  (k  <  16 ) )) {
              c  = (c  +  ((uint64_t)r [k ]) );
              r [k ] = ((uint32_t)c );
              c  = (c  >>  32 );
              k  = (k  +  1 );
          }
        }
      }
  }
}
static int u_top_zero (const uint32_t * a ) {
  for (int i  = 8; (i  <  16 ); (++i )) {
      if (a [i ] !=  0 )
        return 0;
  }
  return 1;
}
static int u_cmp9 (const uint32_t * r , const uint32_t * m ) {
  if (r [8] !=  0 )
    return 1;
  return u_cmp (r , m );
}
static void u_sub9 (uint32_t * r , const uint32_t * m ) {
  { /* let212 */
    int64_t br  = 0;
    // ----------
    for (int i  = 0; (i  <  9 ); (++i )) {
        { /* let217 */
          int64_t mv  = (((i  <  8 )) ? ((int64_t)m [i ]) : 0);
          int64_t d  = 0;
          // ----------
          d  = ((((int64_t)r [i ]) -  mv  ) -  br  );
          if (d  <  0 )
            { /* block221 */
              d  = (d  +  4294967296 );
              br  = 1;
            }
          else
            br  = 0;
          r [i ] = ((uint32_t)d );
        }
    }
  }
}
static int u_divmod (const uint32_t * a , const uint32_t * m , uint32_t * q , uint32_t * r ) {
  if (u_zero_p (m ))
    return 0;
  { /* let227 */
    uint32_t rem [9];
    // ----------
    for (int i  = 0; (i  <  9 ); (++i )) {
        rem [i ] = 0;
    }
    for (int i  = 0; (i  <  16 ); (++i )) {
        q [i ] = 0;
    }
    for (int i  = 511; (i  >=  0 ); (--i )) {
        { /* let238 */
          uint32_t carry  = 0;
          // ----------
          for (int j  = 0; (j  <  9 ); (++j )) {
              { /* let243 */
                uint32_t nc  = (rem [j ] >>  31 );
                // ----------
                rem [j ] = ((rem [j ] <<  1 ) |  carry  );
                carry  = nc ;
              }
          }
        }
        rem [0] = (rem [0] |  ((a [(i  >>  5 )] >>  (i  &  31 ) ) &  1 ) );
        if (u_cmp9 (rem , m ) >=  0 )
          { /* block247 */
            u_sub9 (rem , m );
            q [(i  >>  5 )] = (q [(i  >>  5 )] |  (((uint32_t)1) <<  (i  &  31 ) ) );
          }
    }
    for (int i  = 0; (i  <  8 ); (++i )) {
        r [i ] = rem [i ];
    }
  }
  return 1;
}
static int u_divmod8 (const uint32_t * a , const uint32_t * m , uint32_t * q , uint32_t * r ) {
  { /* let253 */
    uint32_t wide [16];
    uint32_t qw [16];
    // ----------
    for (int i  = 0; (i  <  16 ); (++i )) {
        wide [i ] = 0;
    }
    for (int i  = 0; (i  <  8 ); (++i )) {
        wide [i ] = a [i ];
    }
    if (!u_divmod (wide , m , qw , r ))
      return 0;
    for (int i  = 0; (i  <  8 ); (++i )) {
        q [i ] = qw [i ];
    }
  }
  return 1;
}
static uint32_t u_divmod_small (uint32_t * q , const uint32_t * a , uint32_t d ) {
  { /* let267 */
    uint64_t r  = 0;
    // ----------
    for (int i  = 7; (i  >=  0 ); (--i )) {
        { /* let272 */
          uint64_t cur  = ((r  <<  32 ) |  ((uint64_t)a [i ]) );
          // ----------
          q [i ] = ((uint32_t)(cur  /  ((uint64_t)d ) ));
          r  = (cur  %  ((uint64_t)d ) );
        }
    }
    return ((uint32_t)r );
  }
}
static uint32_t u_mul_small_add (uint32_t * a , uint32_t mul , uint32_t add ) {
  { /* let275 */
    uint64_t c  = ((uint64_t)add );
    // ----------
    for (int i  = 0; (i  <  8 ); (++i )) {
        c  = (c  +  (((uint64_t)a [i ]) *  ((uint64_t)mul ) ) );
        a [i ] = ((uint32_t)c );
        c  = (c  >>  32 );
    }
    return ((uint32_t)c );
  }
}
static int u_bits (const uint32_t * a ) {
  for (int i  = 7; (i  >=  0 ); (--i )) {
      if (a [i ] !=  0 )
        { /* block286 */
          for (int b  = 31; (b  >=  0 ); (--b )) {
              if (0 !=  ((a [i ] >>  b  ) &  1 ) )
                return ((i  *  32 ) +  (b  +  1 ) );
          }
        }
  }
  return 0;
}
static void u_shr1 (uint32_t * a ) {
  for (int i  = 0; (i  <  8 ); (++i )) {
      a [i ] = ((a [i ] >>  1 ) |  (((i  <  7 )) ? ((a [(i  +  1 )] &  1 ) <<  31 ) : 0) );
  }
}
static void u_sqrt (uint32_t * r , const uint32_t * a ) {
  if (u_zero_p (a ))
    { /* block300 */
      u_set0 (r );
      return ;
    }
  { /* let302 */
    int n  = u_bits (a );
    // ----------
    if (n  <=  1 )
      { /* block306 */
        u_set1 (r , 1);
        return ;
      }
    { /* let308 */
      uint32_t x [8];
      uint32_t y [8];
      uint32_t q [8];
      uint32_t rem [8];
      int p  = 0;
      // ----------
      p  = ((n  /  2 ) +  1 );
      if (p  >  255 )
        p  = 255;
      u_set0 (x );
      x [(p  >>  5 )] = (((uint32_t)1) <<  (p  &  31 ) );
      while (1) {
          if (!u_divmod8 (a , x , q , rem ))
            { /* block316 */
              u_set0 (r );
              return ;
            }
          if (0 !=  u_add (y , x , q ) )
            { /* block320 */
              u_shr1 (y );
              y [7] = (y [7] |  0x80000000 );
            }
          else
            u_shr1 (y );
          if (u_cmp (y , x ) >=  0 )
            { /* block325 */
              u_cpy (r , x );
              return ;
            }
          u_cpy (x , y );
      }
    }
  }
}
static int u_nib (char c ) {
  if ((c  >=  ((char)48) ) &&  (c  <=  ((char)57) ) )
    return (((int)c ) -  48 );
  if ((c  >=  ((char)97) ) &&  (c  <=  ((char)102) ) )
    return (10 +  (((int)c ) -  97 ) );
  if ((c  >=  ((char)65) ) &&  (c  <=  ((char)70) ) )
    return (10 +  (((int)c ) -  65 ) );
  return -1;
}
static int u_hex_in (const char * s , size_t len , uint32_t * out ) {
  u_set0 (out );
  if ((len  ==  0 ) ||  (len  >  64 ) )
    return 0;
  for (size_t k  = 0; (k  <  len  ); (++k )) {
      { /* let340 */
        int v  = u_nib (s [((len  -  1 ) -  k  )]);
        // ----------
        if (v  <  0 )
          return 0;
        out [(k  >>  3 )] = (out [(k  >>  3 )] |  (((uint32_t)v ) <<  (4 *  ((int)(k  &  7 )) ) ) );
      }
  }
  return 1;
}
static void u_hex_out (const uint32_t * a , char * hex ) {
  { /* let345 */
    const char * hx  = "0123456789abcdef";
    // ----------
    for (int i  = 0; (i  <  32 ); (++i )) {
        { /* let350 */
          int b  = (((int)(a [(7 -  (i  >>  2 ) )] >>  (8 *  (3 -  (i  &  3 ) ) ) )) &  255 );
          // ----------
          hex [(2 *  i  )] = hx [((b  >>  4 ) &  15 )];
          hex [((2 *  i  ) +  1 )] = hx [(b  &  15 )];
        }
    }
    hex [64] = ((char)0);
  }
}
static int u_dec_in (const char * s , uint32_t * out ) {
  u_set0 (out );
  { /* let353 */
    size_t len  = strlen (s );
    // ----------
    if (len  ==  0 )
      return 0;
    for (size_t k  = 0; (k  <  len  ); (++k )) {
        { /* let360 */
          char c  = s [k ];
          // ----------
          if ((c  <  ((char)48) ) ||  (c  >  ((char)57) ) )
            return 0;
          if (0 !=  u_mul_small_add (out , 10, ((uint32_t)(((int)c ) -  48 ))) )
            return -1;
        }
    }
  }
  return 1;
}
static void u_dec_out (const uint32_t * a , char * dec ) {
  if (u_zero_p (a ))
    { /* block369 */
      dec [0] = ((char)48);
      dec [1] = ((char)0);
      return ;
    }
  { /* let371 */
    char tmp [80];
    int n  = 0;
    uint32_t cur [8];
    uint32_t q [8];
    // ----------
    u_cpy (cur , a );
    while ((!u_zero_p (cur ))) {
        { /* let375 */
          uint32_t d  = u_divmod_small (q , cur , 10);
          // ----------
          tmp [n ] = ((char)(48 +  ((int)d ) ));
          n  = (n  +  1 );
          u_cpy (cur , q );
        }
    }
    for (int i  = 0; (i  <  n  ); (++i )) {
        dec [i ] = tmp [((n  -  1 ) -  i  )];
    }
    dec [n ] = ((char)0);
  }
}
static int u_in (coco_engine * e , size_t slot , uint32_t * out ) {
  { /* let381 */
    int64_t iv  = 0;
    char buf [128];
    // ----------
    if (coco_m_int (e , slot , (&iv )))
      { /* block385 */
        if (iv  <  0 )
          return coco_m_domain_error (e , "a non-negative integer", slot );
        u_set0 (out );
        out [0] = ((uint32_t)(iv  &  4294967295 ));
        out [1] = ((uint32_t)((iv  >>  32 ) &  4294967295 ));
        return 1;
      }
    if (!coco_m_text (e , slot , buf , 128))
      return coco_m_type_error (e , "an integer or a numeric atom", slot );
    if ((buf [0] ==  ((char)48) ) &&  ((buf [1] ==  ((char)120) ) ||  (buf [1] ==  ((char)88) ) ) )
      { /* block393 */
        if (!u_hex_in ((&buf [2]), (strlen (buf ) -  2 ), out ))
          return coco_m_domain_error (e , "at most 64 hexadecimal digits", slot );
        return 1;
      }
    { /* let397 */
      int ok  = u_dec_in (buf , out );
      // ----------
      if (ok  ==  -1 )
        return coco_m_error (e , "u256 overflow", "a decimal above 2^256-1");
      if (ok  ==  0 )
        return coco_m_domain_error (e , "decimal digits or 0x hexadecimal", slot );
    }
    return 1;
  }
}
static int u_out (coco_engine * e , size_t slot , const uint32_t * v ) {
  { /* let404 */
    char dec [96];
    // ----------
    u_dec_out (v , dec );
    return coco_m_unify_atom (e , slot , dec );
  }
}
int u_p_add (coco_engine * e , size_t g ) {
  { /* let408 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t rout  = coco_m_arg (e , g , 2);
    // ----------
    { /* let410 */
      uint32_t a [8];
      uint32_t b [8];
      uint32_t r [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      if (0 !=  u_add (r , a , b ) )
        return coco_m_error (e , "u256 overflow", "the sum is above 2^256-1");
      return u_out (e , rout , r );
    }
  }
}
int u_p_sub (coco_engine * e , size_t g ) {
  { /* let420 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t rout  = coco_m_arg (e , g , 2);
    // ----------
    { /* let422 */
      uint32_t a [8];
      uint32_t b [8];
      uint32_t r [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      if (0 !=  u_sub (r , a , b ) )
        return coco_m_error (e , "u256 underflow", "the difference is below zero");
      return u_out (e , rout , r );
    }
  }
}
int u_p_mul (coco_engine * e , size_t g ) {
  { /* let432 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t rout  = coco_m_arg (e , g , 2);
    // ----------
    { /* let434 */
      uint32_t a [8];
      uint32_t b [8];
      uint32_t w [16];
      uint32_t r [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      u_mul512 (w , a , b );
      if (!u_top_zero (w ))
        return coco_m_error (e , "u256 overflow", "the product is above 2^256-1");
      for (int i  = 0; (i  <  8 ); (++i )) {
          r [i ] = w [i ];
      }
      return u_out (e , rout , r );
    }
  }
}
int u_p_div (coco_engine * e , size_t g ) {
  { /* let447 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t rout  = coco_m_arg (e , g , 2);
    // ----------
    { /* let449 */
      uint32_t a [8];
      uint32_t b [8];
      uint32_t q [8];
      uint32_t rem [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      if (!u_divmod8 (a , b , q , rem ))
        return coco_m_error (e , "u256 division by zero", "the divisor is zero");
      return u_out (e , rout , q );
    }
  }
}
int u_p_mod (coco_engine * e , size_t g ) {
  { /* let459 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t rout  = coco_m_arg (e , g , 2);
    // ----------
    { /* let461 */
      uint32_t a [8];
      uint32_t b [8];
      uint32_t q [8];
      uint32_t rem [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      if (!u_divmod8 (a , b , q , rem ))
        return coco_m_error (e , "u256 division by zero", "the divisor is zero");
      return u_out (e , rout , rem );
    }
  }
}
int u_p_muldiv (coco_engine * e , size_t g ) {
  { /* let471 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t cin  = coco_m_arg (e , g , 2);
    size_t rout  = coco_m_arg (e , g , 3);
    // ----------
    { /* let473 */
      uint32_t a [8];
      uint32_t b [8];
      uint32_t c [8];
      uint32_t w [16];
      uint32_t q [16];
      uint32_t rem [8];
      uint32_t r [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      if (!u_in (e , cin , c ))
        return 0;
      u_mul512 (w , a , b );
      if (!u_divmod (w , c , q , rem ))
        return coco_m_error (e , "u256 division by zero", "the divisor is zero");
      if (!u_top_zero (q ))
        return coco_m_error (e , "u256 overflow", "the quotient is above 2^256-1");
      for (int i  = 0; (i  <  8 ); (++i )) {
          r [i ] = q [i ];
      }
      return u_out (e , rout , r );
    }
  }
}
int u_p_cmp (coco_engine * e , size_t g ) {
  { /* let490 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t bin  = coco_m_arg (e , g , 1);
    size_t rout  = coco_m_arg (e , g , 2);
    // ----------
    { /* let492 */
      uint32_t a [8];
      uint32_t b [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      if (!u_in (e , bin , b ))
        return 0;
      { /* let498 */
        int c  = u_cmp (a , b );
        // ----------
        return coco_m_unify_atom (e , rout , (((c  <  0 )) ? "<" : (((c  >  0 )) ? ">" : "=")));
      }
    }
  }
}
int u_p_sqrt (coco_engine * e , size_t g ) {
  { /* let502 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t rout  = coco_m_arg (e , g , 1);
    // ----------
    { /* let504 */
      uint32_t a [8];
      uint32_t r [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      u_sqrt (r , a );
      return u_out (e , rout , r );
    }
  }
}
int u_p_dec (coco_engine * e , size_t g ) {
  { /* let510 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t rout  = coco_m_arg (e , g , 1);
    // ----------
    { /* let512 */
      uint32_t a [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      return u_out (e , rout , a );
    }
  }
}
int u_p_hex (coco_engine * e , size_t g ) {
  { /* let518 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t rout  = coco_m_arg (e , g , 1);
    // ----------
    { /* let520 */
      uint32_t a [8];
      char hex [70];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      u_hex_out (a , hex );
      return coco_m_unify_atom (e , rout , hex );
    }
  }
}
int u_p_int (coco_engine * e , size_t g ) {
  { /* let526 */
    size_t ain  = coco_m_arg (e , g , 0);
    size_t rout  = coco_m_arg (e , g , 1);
    // ----------
    { /* let528 */
      uint32_t a [8];
      // ----------
      if (!u_in (e , ain , a ))
        return 0;
      for (int i  = 2; (i  <  8 ); (++i )) {
          if (a [i ] !=  0 )
            return coco_m_error (e , "u256 does not fit an integer", "above 2^63-1, so it would wrap");
      }
      if (0 !=  (a [1] &  0x80000000 ) )
        return coco_m_error (e , "u256 does not fit an integer", "above 2^63-1, so it would wrap");
      { /* let539 */
        int64_t v  = ((((int64_t)a [1]) <<  32 ) |  ((int64_t)a [0]) );
        // ----------
        return coco_m_unify_int (e , rout , v );
      }
    }
  }
}
int u_dispatch (coco_engine * e , const char * name , uint32_t arity , size_t g , int * found ) {
  (*found ) = 1;
  if (arity  ==  2 ) {
      if (0 ==  strcmp (name , "u256_sqrt") ) {
          return u_p_sqrt (e , g );
      }
      else if (0 ==  strcmp (name , "u256_dec") ) {
          return u_p_dec (e , g );
      }
      else if (0 ==  strcmp (name , "u256_hex") ) {
          return u_p_hex (e , g );
      }
      else if (0 ==  strcmp (name , "u256_int") ) {
          return u_p_int (e , g );
      }
      else if (true ) {
          (*found ) = 0;
          return 0;
      }
  }
  else if (arity  ==  3 ) {
      if (0 ==  strcmp (name , "u256_add") ) {
          return u_p_add (e , g );
      }
      else if (0 ==  strcmp (name , "u256_sub") ) {
          return u_p_sub (e , g );
      }
      else if (0 ==  strcmp (name , "u256_mul") ) {
          return u_p_mul (e , g );
      }
      else if (0 ==  strcmp (name , "u256_div") ) {
          return u_p_div (e , g );
      }
      else if (0 ==  strcmp (name , "u256_mod") ) {
          return u_p_mod (e , g );
      }
      else if (0 ==  strcmp (name , "u256_cmp") ) {
          return u_p_cmp (e , g );
      }
      else if (true ) {
          (*found ) = 0;
          return 0;
      }
  }
  else if (arity  ==  4 ) {
      if (0 ==  strcmp (name , "u256_muldiv") ) {
          return u_p_muldiv (e , g );
      }
      else if (true ) {
          (*found ) = 0;
          return 0;
      }
  }
  else if (true ) {
      (*found ) = 0;
      return 0;
  }
}
int coco_library_entry () {
  if (!coco_module_register ("u256", u_dispatch , NULL , NULL ))
    return 0;
  return 1;
}
