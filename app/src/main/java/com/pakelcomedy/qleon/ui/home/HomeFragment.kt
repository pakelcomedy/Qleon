package com.pakelcomedy.qleon.ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.viewpager2.widget.ViewPager2
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentHomeBinding

class HomeFragment : Fragment(R.layout.fragment_home) {

    private var _binding: FragmentHomeBinding? = null
    private val binding get() = _binding!!

    private val viewModel: HomeViewModel by viewModels() // ViewModel to store selected tab

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Initialize ViewPager with Adapter
        val adapter = HomeViewPagerAdapter(requireActivity())
        binding.viewPager.adapter = adapter

        // Set default selection from ViewModel
        binding.viewPager.currentItem = viewModel.selectedTabIndex
        updateTabUI(viewModel.selectedTabIndex)

        // Set up ViewPager change listener
        binding.viewPager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                super.onPageSelected(position)
                // Update the selected tab index in the ViewModel
                viewModel.selectedTabIndex = position
                updateTabUI(position)
            }
        })

        // Set click listener for "Chats" navigation
        binding.chatsText.setOnClickListener {
            binding.viewPager.currentItem = 0
        }

        // Set click listener for "New Chat" navigation
        binding.newChatText.setOnClickListener {
            binding.viewPager.currentItem = 1
        }
    }

    private fun updateTabUI(position: Int) {
        when (position) {
            0 -> {
                // Highlight "Chats" tab
                binding.chatsText.setTextColor(requireContext().getColor(R.color.white))
                binding.chatsText.setTypeface(null, android.graphics.Typeface.BOLD)
                binding.chatsUnderline.visibility = View.VISIBLE

                // Dim "New Chat" tab
                binding.newChatText.setTextColor(requireContext().getColor(R.color.gray))
                binding.newChatText.setTypeface(null, android.graphics.Typeface.NORMAL)
                binding.newChatUnderline.visibility = View.GONE
            }
            1 -> {
                // Highlight "New Chat" tab
                binding.newChatText.setTextColor(requireContext().getColor(R.color.white))
                binding.newChatText.setTypeface(null, android.graphics.Typeface.BOLD)
                binding.newChatUnderline.visibility = View.VISIBLE

                // Dim "Chats" tab
                binding.chatsText.setTextColor(requireContext().getColor(R.color.gray))
                binding.chatsText.setTypeface(null, android.graphics.Typeface.NORMAL)
                binding.chatsUnderline.visibility = View.GONE
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}