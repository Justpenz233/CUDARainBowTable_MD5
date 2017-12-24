#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cstdlib>
#include <cstdio>
#include <stdint.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <ctime>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define MAXTHREAD MaxSM*MaxSP

#define MAXCreate 100
//How many RainBow Table do you want to create
#define BlockNum 4194304
//The max num in per block

//md5:a 128 bit,standard
//md5str:32 chars--->when input,we pack it into the standard version
//when we calculate or work or save or we input from the table file we saved we use the standard version
//when we ouput or input from the stdin the md5,we use the md5str

#define MinC  '0'
#define MaxC  '9'
#define CHCNT 10
#define SPCH 0
#define CHAINLEN 1200
#define RDCTCNT 4

using namespace std;

int DeviceNum;
int MaxSP, MaxSM;
char Begin[BlockNum * 8 + 1], End[BlockNum * 8 + 1];
int begin_len[BlockNum + 1], end_len[BlockNum + 1];

__device__ void MD5(char *src, int src_len, uint32_t *rslt) { //size_t
//the md5 will store at rslt
// leftrotate function definition
//attention:the strlen(src) should <=8
#define LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

	// Message (to prepare)
	uint8_t tmp[128];//lilun shang zhiyao 64,but wanyi...
	uint8_t *msg = tmp;
	uint16_t prei;

	// Note: All variables are unsigned 32 bit and wrap modulo 2^32 when calculating

	// r specifies the per-round shift amounts

	uint32_t r[] = {7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
	                5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
	                4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
	                6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
	               };

	// Use binary integer part of the sines of integers (in radians) as constants// Initialize variables:
	uint32_t k[] = {
		0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
		0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
		0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
		0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
		0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
		0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
		0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
		0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
		0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
		0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
		0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
		0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
		0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
		0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
		0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
		0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
	};

	(*(rslt + 0)) = 0x67452301;
	(*(rslt + 1)) = 0xefcdab89;
	(*(rslt + 2)) = 0x98badcfe;
	(*(rslt + 3)) = 0x10325476; //the magic number

	int new_len = 56; //as the max_length is 8,the new_len must be 56
	//place soruce data
	//add a bit of 1
	//add bits of 0 until have 448 bits
	//the rest
	for (prei = 0; prei < src_len; prei++) *(msg + prei) = *(src + prei);
	*(msg + prei++) = 128; // write the "1" bit

	while (prei < new_len)
		*(msg + prei++) = 0;
	*(msg + prei++) = 8 * src_len;
	while (prei < 128) //lilun shang zhixuyao 64,but wanyi...
		*(msg + prei++) = 0;

	// Process the message in successive 512-bit chunks:
	//for each 512-bit chunk of message:
	int offset;
	for (offset = 0; offset < new_len; offset += (512 / 8)) {

		// break chunk into sixteen 32-bit words w[j], 0 ≤ j ≤ 15
		uint32_t *w = (uint32_t *) (msg + offset);

#ifdef DEBUG
		printf("offset: %d %x\n", offset, offset);

		int j;
		for (j = 0; j < 64; j++) printf("%x ", ((uint8_t *) w)[j]);
		puts("");
#endif

		// Initialize hash value for this chunk:
		uint32_t a = (*(rslt + 0));
		uint32_t b = (*(rslt + 1));
		uint32_t c = (*(rslt + 2));
		uint32_t d = (*(rslt + 3));

		// Main loop:
		uint32_t i;
		for (i = 0; i < 64; i++) {

#ifdef ROUNDS
			uint8_t *p;
			printf("%i: ", i);
			p = (uint8_t *)&a;
			printf("%2.2x%2.2x%2.2x%2.2x ", p[0], p[1], p[2], p[3], a);

			p = (uint8_t *)&b;
			printf("%2.2x%2.2x%2.2x%2.2x ", p[0], p[1], p[2], p[3], b);

			p = (uint8_t *)&c;
			printf("%2.2x%2.2x%2.2x%2.2x ", p[0], p[1], p[2], p[3], c);

			p = (uint8_t *)&d;
			printf("%2.2x%2.2x%2.2x%2.2x", p[0], p[1], p[2], p[3], d);
			puts("");
#endif


			uint32_t f, g;

			if (i < 16) {
				f = (b & c) | ((~b) & d);
				g = i;
			} else if (i < 32) {
				f = (d & b) | ((~d) & c);
				g = (5 * i + 1) % 16;
			} else if (i < 48) {
				f = b ^ c ^ d;
				g = (3 * i + 5) % 16;
			} else {
				f = c ^ (b | (~d));
				g = (7 * i) % 16;
			}

#ifdef ROUNDS
			printf("f=%x g=%d w[g]=%x\n", f, g, w[g]);
#endif
			uint32_t temp = d;
			d = c;
			c = b;
			b = b + LEFTROTATE((a + f + k[i] + w[g]), r[i]);
			a = temp;
		}

		// Add this chunk's hash to result so far:

		(*(rslt + 0)) += a;
		(*(rslt + 1)) += b;
		(*(rslt + 2)) += c;
		(*(rslt + 3)) += d;
	}
}
__device__ void work(char end) {

}

__device__ void rdct(int step_id, const char *md5, char *pwd, int *len)
{	//md5 reduct to a passwd,save to pwd. and the length save to len
	//int id;//??? need li si qi jie jue
	unsigned long long hash = 0ll;
	unsigned int i;
	unsigned int *h1;
	switch (step_id % RDCTCNT) {
	case 0:
		for (i = 0; i < 16; i++)
			hash = hash * 131 + (*(md5 + i));
		break;
	case 1:
		h1 = (unsigned int*)(&hash);
		i = *((unsigned int*)(md5));
		i = ~i + (i << 15);
		i = i ^ (i >> 12);
		i = i + (i << 2);
		i = i ^ (i >> 4);
		i = i * 2057;
		i = i ^ (i >> 16);
		*h1 = i; //get the high 32bits
		i = *((unsigned int*)(md5 + 8));
		i = ~i + (i << 15);
		i = i ^ (i >> 12);
		i = i + (i << 2);
		i = i ^ (i >> 4);
		i = i * 2057;
		i = i ^ (i >> 16);
		*(h1 + 1) = i;
		break;
	case 2:
		h1 = (unsigned int*)(&hash);
		i = *((unsigned int*)(md5 + 4));
		i = ~i + (i << 15);
		i = i ^ (i >> 12);
		i = i + (i << 2);
		i = i ^ (i >> 4);
		i = i * 2057;
		i = i ^ (i >> 16);
		*h1 = i; //get the high 32bits
		i = *((unsigned int*)(md5 + 12));
		i = ~i + (i << 15);
		i = i ^ (i >> 12);
		i = i + (i << 2);
		i = i ^ (i >> 4);
		i = i * 2057;
		i = i ^ (i >> 16);
		*(h1 + 1) = i;
		break;
	case 3:
		uint16_t *p = (uint16_t *)md5;
		*len = 8;
		for (int i = 0; i < 8; i++) *(pwd + i) = (char)(((*(p + i)**(p + i) * 163) % 19163 % CHCNT) + MinC);
		return;
	}
	for (i = 0; hash && i < 8; i++) {
		*(pwd + i) = (char)((hash % CHCNT) + MinC);
		hash /= CHCNT;
	}
	*len = i;
	for (i = 0; i < 8; i++) *(pwd + i) = SPCH;
}

__global__ void CreateRainBow_chain(char *ed, int *len) {
	int id = threadIdx.x + blockDim.x * blockIdx.x;
	//now i assum id is the id th passwd
	char md5[16];//i don konw whether it
	for (int i = 0; i < CHAINLEN; i++) {
		MD5(ed + id * 8, *(len + id), (uint32_t*)md5);
		rdct(i, md5, ed, len);
	}
}
/*__device__ void printToFile() {

}*/

__host__ inline void print_to_file(int fi)
{
	char name[5];
	sprintf_s(name, "%.04d", fi);
	ofstream out(name, ios::binary);
	out.write(End, BlockNum * sizeof(char) * 8);
	out.close();
}

__host__ inline void randBegin() {

	for (int id = 0; id < BlockNum; id++) {
		int len = rand() % 8 + 1;
		if (len <= 3) len = rand() % 8 + 1; //add by lly
		end_len[id] = begin_len[id] = (uint8_t)len;
		int i;
		for (i = 0; i < len; i++) {
			End[id * 8 + i] = Begin[id * 8 + i] = (char)(rand() % (MaxC - MinC) + MinC);
		}
		for (; i < 8; i++) End[id * 8 + i] = Begin[id * 8 + i] = 0;
	}

}

int main()
{
	int num;
	cudaDeviceProp prop;
	cudaGetDeviceCount(&num);
	for (int i = 0; i < num; i++)
	{
		cudaGetDeviceProperties(&prop, i);
		MaxSM = prop.multiProcessorCount;
		MaxSP = prop.maxThreadsPerBlock;
	}
	dim3 grid(MaxSM, 1, 1), block(MaxSP, 1, 1);

	srand((unsigned)time(NULL));
	randBegin();//get random begin,save at the array:Begin

	for (int i = 0; i <= MAXCreate / MAXTHREAD; i++) {
		char *tring_dev; int *temp; int *len;
		cudaMalloc((void **)&temp, sizeof(int));
		cudaMalloc((void **)&tring_dev, BlockNum * 8 * sizeof(char));
		cudaMalloc((void **)&len, BlockNum * sizeof(uint8_t));

		cudaMemcpy(temp, &i, sizeof(int), cudaMemcpyHostToDevice);
		cudaMemcpy(tring_dev, End, BlockNum * 8 * sizeof(char), cudaMemcpyHostToDevice);
		cudaMemcpy(len, end_len, BlockNum * sizeof(uint8_t), cudaMemcpyHostToDevice);

		CreateRainBow_chain <<< grid, block>>> (tring_dev, len);

		cudaMemcpy(End, tring_dev, BlockNum * 8 * sizeof(char), cudaMemcpyDeviceToHost);
		cudaMemcpy(end_len, len, BlockNum * sizeof(uint8_t), cudaMemcpyDeviceToHost);

		cudaFree(tring_dev); cudaFree(temp); cudaFree(len);
		print_to_file(i);
		//printToFile();
	}

	system("pause");
}
