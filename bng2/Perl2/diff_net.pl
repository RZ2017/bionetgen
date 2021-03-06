#!/usr/bin/perl
# compare two BNGL network files:
# determines if (1) species set is different.
#               (2) reaction set is different.
# no other comparisons are made!
#
# usage: diff_net.pl bngl1.net bngl2.net > output
#
# author: justin.s.hogg@gmail.com
# last modified: 19mar2009
#
# note: script works correctly in testing, but has no been
# throughly validated.  error checking is minimal.
#
# Current script will only work if reactions are specified
# using species indices (rather than strings generated by
# keyword "TextReaction").
# 
# Challenge: Different species string generators will produce non-matching results.
#  We need a comparison method that is independent of the species string.
# Possibility: use SpeciesGraph module to read species string and use
# HNauty to generate strings.

use warnings;
use strict;

# use version $Id: SpeciesGraph.pm,v 1.23 2007/07/06 04:47:25 faeder Exp $
# use SpeciesGraph;  


# get bngl file names from command line
print "> comparing BNGL network files.\n";
my ($file1, $file2) = @ARGV;

# parse bngl files and return species list and reaction list
my ($slist1, $rlist1) = parse_bngl($file1);
my ($slist2, $rlist2) = parse_bngl($file2);

# find unique species in each list
print "> comparing species sets.\n";
my $print_unique_species = generate_print_unique( 'species', \&stringify_species );
my ($unique_slist1, $unique_slist2) = compare_lists( $slist1, $slist2,
                                                     \&compare_species, $print_unique_species );

if (@$unique_slist1)
{  # foreach unique species, determine which rules create it.   
   print_yielding_reactions( $unique_slist1, $rlist1, 1 );  
}

if (@$unique_slist2)
{  # foreach unique species, determine which rules create it.   
   print_yielding_reactions( $unique_slist2, $rlist2, 2 );  
}

# if species set are identical, then check if reactions are identical
unless ( @$unique_slist1  or  @$unique_slist2 )
{
   print "> comparing reaction sets.\n";
   my $print_unique_rxns = generate_print_unique( 'reaction', \&stringify_reaction );

   # map species set 2 into set 1
   my $smap = map_species( $slist1, $slist2 );

   # translate reaction list 2
   my $rlist2 = translate_reactions( $rlist2, $smap );
  
   # compare reactions
   my ($unique_rlist1, $unique_rlist2) = compare_lists( $rlist1, $rlist2,
                                                        \&compare_reactions, $print_unique_rxns );
}

print "> done comparing network files.\n";
exit 0;




### ------------------- ###
### accessory functions ###
### ------------------- ###


sub parse_bngl
# (\@species_list, \@reaction_list) = parse_bngl( $filename )
# parse BNGL network file and generate species and reaction lists
{
   my $file = shift;
   print "> parsing bngl file $file.\n";   
   open( FILE, '<', $file );

   my $species_list = [];
   my $reaction_list = [];

   my $species_block = 0;
   my $reaction_block = 0;
   while ( my $line = <FILE> )
   {
      if ($species_block)
      {
         if ( $line =~ /^end species/ )
         {  $species_block = 0;  }
         else
         {
            my ($idx, $species_string) = ( $line =~ /^\s*(\d+)\s+(\S+)/ ); 
            my $species =
            {
               'index'  => $idx,
               'string' => process_species_string($species_string),
            };
            push @$species_list, $species;
         }  
      }
      elsif ($reaction_block)
      {
         if ( $line =~ /^end reactions/ )
         {  $reaction_block = 0;  }
         else
         {
            my ($idx, $reactants, $products, $ratelaw, $rule)
               = ( $line =~ /^\s*(\d+)\s+([\d,]+)\s+([\d,]+)\s+(\S+)\s+#(\w+)/ );
            my $rxn =
            {
               'index'     => $idx,
               'reactants' => [ split /,/, $reactants ],
               'products'  => [ split /,/,  $products ],
               'ratelaw'   => $ratelaw,
               'rule'      => $rule
            };
            push @$reaction_list, $rxn;
         }
      }
      elsif ( $line =~ /^begin species/ )
      {  $species_block = 1;   }
      elsif ( $line =~ /^begin reactions/ )
      {  $reaction_block = 1;  }
   }   

   close FILE;
   return ($species_list, $reaction_list);
}




sub process_species_string
# $new_string = process_species_string( $old_string )
# sorts the molecules in a species alphabetically
{
   my $species_string = shift;
#   my ($head) = ( $species_string =~ s/^([^+>]+::)\s*// );
#   my @molecules = ( split /\./, $species_string );
   
   # reconstruct string in alpha-numeric ordering
#   $species_string = $head;
#   foreach my $molecule ( sort {$a cmp $b} @molecules )
#   {  $species_string .= $molecule . '.';  }

   # remove trailing '.'
#   chop $species_string; 
       
   return $species_string;
}




sub compare_lists
# (\@unique_set1, \@unique_set2) = compare_lists( \@list1, \@list2, \&compare_fcn, \&print_fcn )
# compares two lists and identified unique elements.
# &compare_fcn is a subroutine which compares elements in the lists (like cmp or <=>).
# &print_fcn is a subroutine which prints unique elements in the lists (see examples below).
{
   my ($list1, $list2, $compare_fcn, $print_fcn) = @_;
   my $unique1 = [];
   my $unique2 = [];
 
   # sort lists
   @$list1 = ( sort $compare_fcn @$list1 );
   @$list2 = ( sort $compare_fcn @$list2 );

   # compare lists
   my $idx1 = 0;
   my $idx2 = 0;
   while ( $idx1 < @$list1  and  $idx2 < @$list2 )
   {  
      my $compare = &$compare_fcn( $list1->[$idx1], $list2->[$idx2] );

      if ( $compare == 0 )
      { # items are the same
         $idx1++;
         $idx2++;
      }
      elsif ( $compare == 1 )
      { # item on list2 is unique
         push @$unique2, $list2->[$idx2];
         $idx2++;
      }
      elsif ( $compare == -1 )
      { # item on list1 is unique
         push @$unique1, $list1->[$idx1];
         $idx1++;
      } 
   }

   # everything remaining in $list1 is unique
   while ( $idx1 < @$list1 )
   {
      push @$unique1, $list1->[$idx1];
      $idx1++;
   }

   # everything remaining in $list2 is unique
   while ( $idx2 < @$list2 )
   {
      push @$unique2, $list2->[$idx2];
      $idx2++;
   }

   &$print_fcn( $unique1, $unique2 );     
   return ($unique1, $unique2);
}




sub compare_species
# $int = compare_species( $sp1, $sp2 )
# compares two species based on string representation.
# returns one of -1, 0, or 1.  (like cmp) 
{
   my ($s1, $s2);

   if ( defined $a  and  defined $b )
   {  $s1 = $a;  $s2 = $b;  }
   else
   {  ($s1, $s2) = @_;  }
   
   return $s1->{string} cmp $s2->{string};
}




sub compare_reactions
# $int = compare_reactions( $rxn1, $rxn2 )
# compares two reactions based on reactants and products (only!).
# returns one of -1, 0, or 1.  (like cmp) 
{
   my ($r1, $r2);
   
   if ( defined $a  and  defined $b )
   {  $r1 = $a;  $r2 = $b;  }
   else
   {  ($r1, $r2) = @_;  }

   my @array1 = ( sort {$a<=>$b} @{$r1->{reactants}}, -1, sort {$a<=>$b} @{$r1->{products}} );
   my @array2 = ( sort {$a<=>$b} @{$r2->{reactants}}, -1, sort {$a<=>$b} @{$r2->{products}} );    
        
   return compare_number_arrays( \@array1, \@array2 );
}




sub compare_number_arrays
# $int = compare_number_arrays( $a1, $a2 )
# compares two numeric arrays.  longer arrays are "bigger".  arrays of same length
# are compared element by element.  The array with the larger element at the first
# difference is considered "bigger".
# returns one of -1, 0, or 1.  (like cmp) 
{
   my ($a1, $a2) = @_;
   
   my $cmp = scalar(@$a1) cmp scalar(@$a2);
   if ($cmp) { return $cmp; }
   
   foreach my $idx ( 0 .. $#{$a1} )
   {
      $cmp = $a1->[$idx] cmp $a2->[$idx];
      if ($cmp) { return $cmp; }
   }
 
   # arrays are numerically the same  
   return 0;
}




sub generate_print_unique
# \&print_fcn = generate_print_unique( $type, $string_fcn )
# generates an anonymous function that prints unique elements found in comparison.
{
   my ($type, $string_fcn) = @_;

   return sub
   {
      my ($list1, $list2) = @_;

      if ( @$list1 == 0  and @$list2 == 0 )
      {
         print "   ** $type sets are identical.\n"
      }
      else
      {
         printf "   ** %s set1 has %u unique element(s).\n", $type, scalar(@$list1);
         foreach my $item ( sort {$a->{'index'} <=> $b->{'index'}} @$list1 )
         {  printf "      %s\n", &{$string_fcn}($item);  }
         printf "   ** %s set2 has %u unique element(s).\n", $type, scalar(@$list2);
         foreach my $item ( sort {$a->{'index'} <=> $b->{'index'}} @$list2 )
         {  printf "      %s\n", &{$string_fcn}($item);  }
      }
      return 0;
   };
}




sub stringify_reaction
# turn reaction hash into a string
{
   my $rxn = shift;
   return sprintf( "%6d  %s  %s  %s  #%s", $rxn->{'index'}, join(',', @{$rxn->{reactants}}),
                   join(',', @{$rxn->{products}}), $rxn->{ratelaw}, $rxn->{rule} );
}




sub stringify_species
# turn species hash into a string
{
   my $species = shift;
   return sprintf( "%6d  %s", $species->{'index'}, $species->{string} );
}




sub print_yielding_reactions
# 0 = print_yielding_reactions( \@slist, \@rlist, $set_idx )
# finds and prints reactions in @rlist which yield species in @slist.
# $set_idx is just an index for print display.
{
   my ($slist, $rlist, $set_idx) = @_;
   print "> searching for reactions which yield unique species in set $set_idx.\n";
   foreach my $sp ( @$slist )
   {
      printf "   ** Reactions yielding species %s %s:\n", $sp->{'index'}, $sp->{string};
      my $ylist = find_yielding_reactions( $sp, $rlist );
      foreach my $rxn ( @$ylist )
      {  printf "    + reaction: % 6u  rule: %s\n", $rxn->{'index'}, $rxn->{rule};  }
   }  
   return 0;
}




sub find_yielding_reactions
# accessory to print_yielding_reactions
{
   my ($species, $rlist) = @_;       
   my $species_idx = $species->{'index'};
   my $ylist = [];
   
   foreach my $rxn ( @$rlist )
   {
      if ( grep {$_ == $species_idx} @{$rxn->{products}} )
      {  push @$ylist, $rxn;  }
   }
   return $ylist;
}



   
sub map_species
# \%smap = map_species( \@slist1, \@slist2 )
# map species indices in list1 to species indices in list2
# (based on string comparison)
{
   my ($slist1, $slist2) = @_;
   my $smap = {};

   my $sdict1 = build_species_dictionary( $slist1 );
   my $sdict2 = build_species_dictionary( $slist2 );   

   foreach my $sp ( keys %$sdict1 )
   {
      my $idx1 = $sdict1->{$sp};
      my $idx2 = $sdict2->{$sp};
      $smap->{$idx2} = $idx1;
   }
   return $smap;
}




sub build_species_dictionary
# \%sdict = build_species_dictionary( $slist )
# build a map from species strings to indices.
{
   my $slist = shift;
   my $sdict = {};
   
   foreach my $sp (@$slist)
   {  $sdict->{ $sp->{string} } = $sp->{'index'};  }  
   return $sdict;
}




sub translate_reactions
# \@tlist = translate_reactions( \@rlist, \%smap )
# translate a set of rules into a new indexing scheme
# as specified by %smap.
{
   my ($rlist, $smap) = @_;

   # create a container for translated lists;
   my $tlist = [];
   
   foreach my $rxn (@$rlist)   
   {  # copy and translate each reaction
      my $trxn = {};
      %{$trxn} = %{$rxn};
      push @$tlist, $trxn;
 
      # translate reactions
      foreach my $reac ( @{$trxn->{reactants}} )
      {  $reac = $smap->{$reac};  } 
      
      foreach my $prod ( @{$trxn->{products}} )
      {  $prod = $smap->{$prod};  }      
   }
   
   return $tlist;
}

