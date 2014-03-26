#include  "../mshadow/tensor.h"
#include  "../mshadow/tensor_container.h"

template <typename Dtype>
void im2col_cpu(const Dtype* data_im, const int channels,
    const int height, const int width, const int ksize, const int stride,
    Dtype* data_col) {
  int height_col = (height - ksize) / stride + 1;
  int width_col = (width - ksize) / stride + 1;
  int channels_col = channels * ksize * ksize;
  for (int c = 0; c < channels_col; ++c) {
    int w_offset = c % ksize;
    int h_offset = (c / ksize) % ksize;
    int c_im = c / ksize / ksize;
    for (int h = 0; h < height_col; ++h) {
      for (int w = 0; w < width_col; ++w) {
        data_col[(c * height_col + h) * width_col + w] =
            data_im[(c_im * height + h * stride + h_offset) * width
                + w * stride + w_offset];
      }
    }
  }
}

template <typename Dtype>
void col2im_cpu(const Dtype* data_col, const int channels,
    const int height, const int width, const int ksize, const int stride,
    Dtype* data_im) {
  memset(data_im, 0, sizeof(Dtype) * height * width * channels);
  int height_col = (height - ksize) / stride + 1;
  int width_col = (width - ksize) / stride + 1;
  int channels_col = channels * ksize * ksize;
  for (int c = 0; c < channels_col; ++c) {
    int w_offset = c % ksize;
    int h_offset = (c / ksize) % ksize;
    int c_im = c / ksize / ksize;
    for (int h = 0; h < height_col; ++h) {
      for (int w = 0; w < width_col; ++w) {
        data_im[(c_im * height + h * stride + h_offset) * width + w * stride
            + w_offset] += data_col[(c * height_col + h) * width_col + w];
      }
    }
  }
}

using namespace mshadow;
using namespace mshadow::expr;

template<typename xpu, int dim>
inline void Check( Tensor<xpu,dim>& xmat, Tensor<cpu,dim>& cmat ){
    TensorContainer<cpu,dim> txmat(false);
    txmat.Resize( xmat.shape );
    Copy(txmat, xmat);
    for( index_t  i =0; i < cmat.shape.Size(); ++ i ){
        if( fabs( txmat.dptr[i] - cmat.dptr[i])>1e-6 ) printf("error\n");
    }
}

template<typename xpu>
inline void test( int channels, int height, int width, int ksize, int stride ){
    int height_col = (height - ksize) / stride + 1;
    int width_col = (width - ksize) / stride + 1;
    TensorContainer<cpu,3> cimg(false); cimg.Resize( Shape3( channels, height, width));
    TensorContainer<cpu,2> cmat(false); cmat.Resize( Shape2( channels * ksize*ksize, height_col*width_col ) );
    TensorContainer<xpu,3> ximg(false); ximg.Resize( cimg.shape );
    TensorContainer<xpu,2> xmat(false); xmat.Resize( cmat.shape );
    for( index_t  i =0; i < cimg.shape.Size(); ++ i ){
        cimg.dptr[i] = i;
    } 
    Copy( ximg, cimg );
    im2col_cpu( cimg.dptr, channels, height, width, ksize, stride, cmat.dptr );
    xmat = unpack_patch2col( ximg, ksize, stride );
    Check( xmat, cmat );
    col2im_cpu( cmat.dptr, channels, height, width, ksize, stride, cimg.dptr );
    ximg = pack_col2patch( xmat, ximg.shape, ksize, stride );
    Check( ximg, cimg );
}

int main( void ){
    for( int c = 1; c < 3; ++ c )
        for( int h = 5; h < 30; ++ h )
            for( int w = 6; w< 31; ++ w ){
                int kmax = 10;
                if( kmax > h ) kmax = h;
                if( kmax > w ) kmax = w;
                for( int ksize = 5; ksize < kmax; ++ ksize )
                    for( int stride = 1; stride < 8; ++ stride ){
                        test<cpu>( c,h,w,ksize, stride);
                        test<gpu>( c,h,w,ksize, stride);
                    }
            }
    return 0;
}