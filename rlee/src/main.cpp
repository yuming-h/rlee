#include <Rcpp.h>
#include <random>
#include <unordered_map>

using namespace Rcpp;
using namespace std;


// [[Rcpp::export]]
DataFrame create_n_i_sample(int p, int lambda, int n) {
    default_random_engine gen;
    bernoulli_distribution bernoulli(p);
    poisson_distribution poisson(lambda);
    
    unordered_map<int, int> freqs = {};
    
    for (int i = 0; i < n; i++) {
      int n_i = bernoulli(generator) + poisson(generator);
      unordered_map<int, int>::const_iterator got = freqs.find(n_i);
      // if n_i is already in the hashmap
      if (got == freqs.end()) {
        freqs.insert({n_i, 1});
      } else {
        got->second++;
      }
    }
    
    vector<int> col1;
    col1.reserve(freqs.size());
    
    vector<int> col2;
    col2.reserve(freqs.size());
    
    for (auto kv : freqs) {
      col1.push_back(kv.first);
      col2.push_back(kv.second);
    }
    
    return DataFrame::create(
      Named("n_i") = Rcpp::wrap(col1),
      Name("freq") = Rcpp::wrap(col2)
    );
  
}


// You can include R code blocks in C++ files processed with sourceCpp
// (useful for testing and development). The R code will be automatically 
// run after the compilation.
//

