import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:jainverse/Model/BlogModel.dart';
import 'package:jainverse/Presenter/BlogPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/widgets/common/app_header.dart';

class Blog extends StatefulWidget {
  const Blog({super.key});

  @override
  State<Blog> createState() => _BlogState();
}

class _BlogState extends State<Blog> {
  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  // Blog data
  BlogModel? blogModel;
  bool isLoading = true;
  String? errorMessage;

  // Custom tab management
  int selectedCategoryIndex = 0;
  List<BlogCategory> categories = [];
  Map<int, List<Blogs>> categorizedBlogs = {};

  @override
  void initState() {
    super.initState();
    _audioHandler = const MyApp().called();
    _loadBlogs();
  }

  Future<void> _loadBlogs() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final SharedPref sharePrefs = SharedPref();
      final String token = await sharePrefs.getToken() ?? '';

      if (token.isEmpty) {
        setState(() {
          errorMessage = 'User not authenticated. Please log in.';
          isLoading = false;
        });
        return;
      }

      final BlogPresenter presenter = BlogPresenter();
      String response = '';
      try {
        response = await presenter.getBlog(token);
      } catch (e) {
        rethrow;
      }

      if (response.isNotEmpty) {
        final Map<String, dynamic> jsonData = json.decode(response);
        blogModel = BlogModel.fromJson(jsonData);

        if (blogModel != null) {
          _setupCategories();
        }
      }
    } catch (e) {
      String msg = 'Failed to load blogs.';
      try {
        msg = e.toString();
      } catch (_) {}

      setState(() {
        errorMessage = msg;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _setupCategories() {
    if (blogModel == null) return;

    // Create category map from blogCategories in the API response
    final Map<int, String> categoryMap = {};
    for (final category in blogModel!.data.blogCategories) {
      categoryMap[category.id] = category.title;
    }

    // Update blog_cat_name in blogs using the category map
    for (final blog in blogModel!.data.blogs) {
      blog.blog_cat_name = categoryMap[blog.blog_cat_id] ?? '';
    }

    // Prepare categories list with "All" at the beginning
    final newCategories = [
      BlogCategory(id: 0, title: "All", slug: "all"),
      ...blogModel!.data.blogCategories,
    ];

    // Sort categories by title (except "All" which stays first)
    final sortedCategories = [
      newCategories.first, // "All" category
      ...newCategories.skip(1).toList()
        ..sort((a, b) => a.title.compareTo(b.title)),
    ];

    // Build categorized blogs map
    final newCategorized = <int, List<Blogs>>{};
    newCategorized[0] = blogModel!.data.blogs; // All blogs
    for (final blog in blogModel!.data.blogs) {
      newCategorized.putIfAbsent(blog.blog_cat_id, () => []).add(blog);
    }

    setState(() {
      categories = sortedCategories;
      categorizedBlogs = newCategorized;
      selectedCategoryIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().white,
      body: SafeArea(
        child: Column(
          children: [
            // App header
            AppHeader(
              title: 'Blog',
              showBackButton: true,
              showProfileIcon: false,
              onBackPressed: () => Navigator.pop(context),
              backgroundColor: Colors.transparent,
            ),
            // Content area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.r),
                    topRight: Radius.circular(32.r),
                  ),
                ),
                child: StreamBuilder<MediaItem?>(
                  stream: _audioHandler?.mediaItem,
                  builder: (context, snapshot) {
                    final bottomPadding = AppPadding.bottom(
                      context,
                      extra: 50.w,
                    );

                    return Column(
                      children: [
                        // Custom Category tabs
                        if (!isLoading && categories.isNotEmpty)
                          _buildCustomTabBar(),
                        // Content area
                        Expanded(child: _buildContent(bottomPadding)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      height: 56.h,
      margin: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: appColors().gray[50],
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: categories.asMap().entries.map((entry) {
            final int index = entry.key;
            final BlogCategory category = entry.value;
            final bool isSelected = selectedCategoryIndex == index;
            final int count = categorizedBlogs[category.id]?.length ?? 0;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategoryIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? appColors().primaryColorApp
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: appColors().primaryColorApp.withOpacity(0.2),
                            blurRadius: 8.r,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : appColors().gray[600],
                        fontSize: AppSizes.fontNormal,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (count > 0) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 1.w,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : appColors().primaryColorApp.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : appColors().primaryColorApp,
                            fontSize: AppSizes.badgeFontSize + 2.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(double bottomPadding) {
    if (isLoading) {
      // Wrap in scrollable with bottom padding so spinner isn't cut off and
      // there is scrollable space when mini player is present.
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 120.h,
          child: Center(
            child: CircularProgressIndicator(
              color: appColors().primaryColorApp,
            ),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      // Make error state scrollable and respect bottom padding
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 120.h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48.w,
                  color: appColors().gray[400],
                ),
                SizedBox(height: 16.w),
                Text(
                  errorMessage!,
                  style: TextStyle(
                    color: appColors().gray[600],
                    fontSize: AppSizes.fontMedium,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.w),
                ElevatedButton(
                  onPressed: _loadBlogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors().primaryColorApp,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (categories.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 120.h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 48.w,
                  color: appColors().gray[400],
                ),
                SizedBox(height: 16.w),
                Text(
                  'No blogs available',
                  style: TextStyle(
                    color: appColors().gray[600],
                    fontSize: AppSizes.fontMedium,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Get blogs for selected category
    final selectedCategory = categories[selectedCategoryIndex];
    final blogs = categorizedBlogs[selectedCategory.id] ?? [];

    return _buildBlogList(blogs, bottomPadding);
  }

  Widget _buildBlogList(List<Blogs> blogs, double bottomPadding) {
    if (blogs.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 120.h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 48.w,
                  color: appColors().gray[400],
                ),
                SizedBox(height: 16.w),
                Text(
                  'No blogs in this category',
                  style: TextStyle(
                    color: appColors().gray[600],
                    fontSize: AppSizes.fontMedium,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Ensure ListView includes bottom padding so content can scroll into
    // the area reserved for mini-player / navigation.
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 8.w, 20.w, bottomPadding + 8.w),
      itemCount: blogs.length,
      itemBuilder: (context, index) {
        final blog = blogs[index];
        return _BlogCard(blog: blog);
      },
    );
  }
}

// Keep the existing _BlogCard and _BlogDetailModal classes unchanged
class _BlogCard extends StatelessWidget {
  final Blogs blog;

  const _BlogCard({required this.blog});

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  String _stripHtmlTags(String html) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = blog.image.isNotEmpty
        ? '${AppConstant.ImageUrl}images/blogs/${blog.image}'
        : '';
    debugPrint(
      'Building BlogCard for id=${blog.id} title="${blog.title}" imageUrl=$imageUrl',
    );
    return Container(
      margin: EdgeInsets.only(bottom: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blog Image
          if (blog.image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Builder(
                  builder: (context) {
                    final primary = imageUrl;
                    final fallback =
                        '${AppConstant.ImageUrl}images/blogs/${blog.image}';

                    return Image.network(
                      primary,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint(
                          'Image load error for blog id=${blog.id}: $error',
                        );
                        debugPrint('Primary Image URL: $primary');
                        debugPrint('Attempting fallback URL: $fallback');

                        return Image.network(
                          fallback,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error2, stackTrace2) {
                            debugPrint(
                              'Fallback image load error for blog id=${blog.id}: $error2',
                            );
                            debugPrint('Fallback URL: $fallback');
                            return Container(
                              color: appColors().gray[100],
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: appColors().gray[400],
                                  size: 32.w,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: appColors().gray[100],
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: appColors().primaryColorApp,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                          : null,
                                    ),
                                    SizedBox(height: 8.w),
                                    Text(
                                      loadingProgress.expectedTotalBytes != null
                                          ? '${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(0)}%'
                                          : 'Loading...',
                                      style: TextStyle(
                                        color: appColors().gray[500],
                                        fontSize: AppSizes.fontSmall,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: appColors().gray[100],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: appColors().primaryColorApp,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                                SizedBox(height: 8.w),
                                Text(
                                  loadingProgress.expectedTotalBytes != null
                                      ? '${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(0)}%'
                                      : 'Loading...',
                                  style: TextStyle(
                                    color: appColors().gray[500],
                                    fontSize: AppSizes.fontSmall,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                // debug progress
                                SizedBox(height: 4.w),
                                Builder(
                                  builder: (_) {
                                    debugPrint(
                                      'Loading image $primary: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes ?? -1}',
                                    );
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          // Blog Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category and Date Row
                Row(
                  children: [
                    if (blog.blog_cat_name.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.w,
                        ),
                        decoration: BoxDecoration(
                          color: appColors().primaryColorApp.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          blog.blog_cat_name,
                          style: TextStyle(
                            color: appColors().primaryColorApp,
                            fontSize: AppSizes.fontSmall,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _formatDate(blog.created_at),
                      style: TextStyle(
                        color: appColors().gray[500],
                        fontSize: AppSizes.fontSmall,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.w),
                // Blog Title
                Text(
                  blog.title,
                  style: TextStyle(
                    color: appColors().black,
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.w),
                // Blog Preview
                Text(
                  _stripHtmlTags(blog.detail),
                  style: TextStyle(
                    color: appColors().gray[600],
                    fontSize: AppSizes.fontSmall,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.w),
                // Read More Button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _showBlogDetail(context, blog),
                    child: Text(
                      'Read More',
                      style: TextStyle(
                        color: appColors().primaryColorApp,
                        fontSize: AppSizes.fontSmall,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBlogDetail(BuildContext context, Blogs blog) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BlogDetailModal(blog: blog),
    );
  }
}

class _BlogDetailModal extends StatelessWidget {
  final Blogs blog;

  const _BlogDetailModal({required this.blog});

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String detailImageUrl = blog.image.isNotEmpty
        ? '${AppConstant.ImageUrl}images/blogs/${blog.image}'
        : '';
    debugPrint(
      'Opening BlogDetailModal for id=${blog.id} title="${blog.title}" imageUrl=$detailImageUrl',
    );
    return StreamBuilder<MediaItem?>(
      // detect mini player presence and pass bottom padding into modal
      stream: const MyApp().called().mediaItem,
      builder: (context, snapshot) {
        final bottomPadding = AppPadding.bottom(context, extra: 80.w);

        return DraggableScrollableSheet(
          initialChildSize: 0.98,
          minChildSize: 0.75,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 8.w),
                    width: 40.w,
                    height: 4.w,
                    decoration: BoxDecoration(
                      color: appColors().gray[300],
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.w,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            blog.title,
                            style: TextStyle(
                              fontSize: AppSizes.fontLarge,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: appColors().gray[600]),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        left: 20.w,
                        right: 20.w,
                        bottom: bottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meta info
                          Row(
                            children: [
                              if (blog.blog_cat_name.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 6.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appColors().primaryColorApp
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    blog.blog_cat_name,
                                    style: TextStyle(
                                      color: appColors().primaryColorApp,
                                      fontSize: AppSizes.fontSmall,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                _formatDate(blog.created_at),
                                style: TextStyle(
                                  color: appColors().gray[500],
                                  fontSize: AppSizes.fontSmall,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.w),
                          // Blog Image
                          if (blog.image.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Builder(
                                  builder: (context) {
                                    final primary = detailImageUrl;
                                    final fallback =
                                        '${AppConstant.ImageUrl}images/blogs/${blog.image}';

                                    return Image.network(
                                      primary,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        debugPrint(
                                          'Detail image load error for blog id=${blog.id}: $error',
                                        );
                                        debugPrint(
                                          'Primary detail URL: $primary',
                                        );
                                        debugPrint(
                                          'Attempting fallback detail URL: $fallback',
                                        );

                                        return Image.network(
                                          fallback,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error2, stackTrace2) {
                                            debugPrint(
                                              'Fallback detail image load error for blog id=${blog.id}: $error2',
                                            );
                                            return Container(
                                              color: appColors().gray[100],
                                              child: Center(
                                                child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: appColors().gray[400],
                                                  size: 32.w,
                                                ),
                                              ),
                                            );
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              color: appColors().gray[100],
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      color: appColors()
                                                          .primaryColorApp,
                                                      value:
                                                          loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                          : null,
                                                    ),
                                                    SizedBox(height: 8.w),
                                                    Text(
                                                      loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? '${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(0)}%'
                                                          : 'Loading...',
                                                      style: TextStyle(
                                                        color: appColors()
                                                            .gray[500],
                                                        fontSize:
                                                            AppSizes.fontSmall,
                                                        fontFamily: 'Poppins',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        debugPrint(
                                          'Detail image loading $primary: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes ?? -1}',
                                        );
                                        return Container(
                                          color: appColors().gray[100],
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(
                                                  color: appColors()
                                                      .primaryColorApp,
                                                  value:
                                                      loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                      : null,
                                                ),
                                                SizedBox(height: 8.w),
                                                Text(
                                                  loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? '${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(0)}%'
                                                      : 'Loading...',
                                                  style: TextStyle(
                                                    color:
                                                        appColors().gray[500],
                                                    fontSize:
                                                        AppSizes.fontSmall,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          if (blog.image.isNotEmpty) SizedBox(height: 20.w),
                          // Blog Content
                          HtmlWidget(
                            blog.detail,
                            textStyle: TextStyle(
                              fontSize: AppSizes.fontMedium,
                              fontFamily: 'Poppins',
                              height: 1.6,
                              color: appColors().gray[700],
                            ),
                          ),
                          SizedBox(height: 32.w),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
